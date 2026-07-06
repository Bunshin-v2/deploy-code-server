import got from "got";
import type { Droplet } from "../../lib/digitalOcean";
import {
  getPublicIp,
  isPermissionError,
  isCodeServerLive,
  handleErrorLog,
  getUserDataScript,
  deployDigitalOcean,
} from "../../deploys/deployDigitalOcean";

jest.mock("got", () => {
  const textFn = jest.fn();
  const jsonFn = jest.fn();
  const postFn = jest.fn(() => ({ json: jsonFn }));
  const getFn = Object.assign(
    jest.fn(() => ({ text: textFn, json: jsonFn, statusCode: 200 })),
    {
      post: postFn,
      HTTPError: class HTTPError extends Error {
        response: { statusCode: number };
        constructor(statusCode: number) {
          super("HTTPError");
          this.response = { statusCode };
        }
      },
    }
  );
  (getFn as any).__textFn = textFn;
  (getFn as any).__jsonFn = jsonFn;
  (getFn as any).__postFn = postFn;
  return { __esModule: true, default: getFn };
});

jest.mock("inquirer", () => ({
  __esModule: true,
  default: {
    prompt: jest.fn(),
  },
}));

jest.mock("ora", () => {
  const spinner = {
    start: jest.fn().mockReturnThis(),
    stop: jest.fn().mockReturnThis(),
  };
  return { __esModule: true, default: jest.fn(() => spinner) };
});

jest.mock("../../lib/digitalOcean", () => ({
  createDroplet: jest.fn(),
  getDroplet: jest.fn(),
}));

jest.mock("async-wait-until", () => ({
  __esModule: true,
  default: jest.fn(async (predicate: () => Promise<boolean>) => {
    const result = await predicate();
    if (!result) throw new Error("Timed out");
    return result;
  }),
}));

const mockedGot = got as unknown as jest.Mock & {
  post: jest.Mock;
  HTTPError: new (statusCode: number) => Error & {
    response: { statusCode: number };
  };
  __textFn: jest.Mock;
  __jsonFn: jest.Mock;
  __postFn: jest.Mock;
};

beforeEach(() => {
  jest.clearAllMocks();
  jest.spyOn(console, "log").mockImplementation(() => {});
});

afterEach(() => {
  (console.log as jest.Mock).mockRestore();
});

const makeDroplet = (overrides: Partial<Droplet> = {}): Droplet => ({
  id: "1",
  name: "code-server",
  networks: { v4: [] },
  status: "new",
  ...overrides,
});

describe("getPublicIp", () => {
  it("returns the public IP when one exists", () => {
    const droplet = makeDroplet({
      networks: {
        v4: [
          { ip_address: "10.0.0.1", type: "private" },
          { ip_address: "203.0.113.1", type: "public" },
        ],
      },
    });
    expect(getPublicIp(droplet)).toBe("203.0.113.1");
  });

  it("returns undefined when no public network exists", () => {
    const droplet = makeDroplet({
      networks: { v4: [{ ip_address: "10.0.0.1", type: "private" }] },
    });
    expect(getPublicIp(droplet)).toBeUndefined();
  });

  it("returns undefined when v4 array is empty", () => {
    const droplet = makeDroplet({ networks: { v4: [] } });
    expect(getPublicIp(droplet)).toBeUndefined();
  });

  it("returns the first public IP when multiple exist", () => {
    const droplet = makeDroplet({
      networks: {
        v4: [
          { ip_address: "198.51.100.1", type: "public" },
          { ip_address: "198.51.100.2", type: "public" },
        ],
      },
    });
    expect(getPublicIp(droplet)).toBe("198.51.100.1");
  });
});

describe("isPermissionError", () => {
  it("returns true for a 401 HTTPError", () => {
    const error = new mockedGot.HTTPError(401);
    expect(isPermissionError(error)).toBe(true);
  });

  it("returns false for a non-401 HTTPError", () => {
    const error = new mockedGot.HTTPError(403);
    expect(isPermissionError(error)).toBe(false);
  });

  it("returns false for a generic Error", () => {
    expect(isPermissionError(new Error("fail"))).toBe(false);
  });

  it("returns false for non-error values", () => {
    expect(isPermissionError(null)).toBe(false);
    expect(isPermissionError(undefined)).toBe(false);
    expect(isPermissionError("string")).toBe(false);
  });
});

describe("isCodeServerLive", () => {
  it("returns true when got returns status 200", async () => {
    mockedGot.mockReturnValue({ statusCode: 200 });
    const droplet = makeDroplet({
      networks: {
        v4: [{ ip_address: "1.2.3.4", type: "public" }],
      },
    });
    const result = await isCodeServerLive(droplet);
    expect(result).toBe(true);
    expect(mockedGot).toHaveBeenCalledWith("http://1.2.3.4", { retry: 0 });
  });

  it("returns false when got throws an error", async () => {
    mockedGot.mockImplementation(() => {
      throw new Error("Connection refused");
    });
    const droplet = makeDroplet({
      networks: {
        v4: [{ ip_address: "1.2.3.4", type: "public" }],
      },
    });
    const result = await isCodeServerLive(droplet);
    expect(result).toBe(false);
  });

  it("returns false when got returns a non-200 status", async () => {
    mockedGot.mockReturnValue({ statusCode: 503 });
    const droplet = makeDroplet({
      networks: {
        v4: [{ ip_address: "1.2.3.4", type: "public" }],
      },
    });
    const result = await isCodeServerLive(droplet);
    expect(result).toBe(false);
  });
});

describe("handleErrorLog", () => {
  it("logs permission message for a 401 error", () => {
    const error = new mockedGot.HTTPError(401);
    handleErrorLog(error);
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining("Invalid token")
    );
  });

  it("logs generic message for non-permission errors", () => {
    handleErrorLog(new Error("something"));
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining("Something wrong happened")
    );
  });
});

describe("getUserDataScript", () => {
  it("fetches the launch script from GitHub", async () => {
    mockedGot.__textFn.mockResolvedValue("#!/bin/bash\necho hi");
    mockedGot.mockReturnValue({ text: mockedGot.__textFn });

    const result = await getUserDataScript();
    expect(mockedGot).toHaveBeenCalledWith(
      "https://raw.githubusercontent.com/cdr/deploy-code-server/main/deploy-vm/launch-code-server.sh"
    );
    expect(result).toBe("#!/bin/bash\necho hi");
  });
});

describe("deployDigitalOcean", () => {
  const inquirer = require("inquirer").default;
  const { createDroplet, getDroplet } = require("../../lib/digitalOcean");

  it("runs the full deploy flow successfully", async () => {
    const activeDroplet = makeDroplet({
      id: "42",
      status: "active",
      networks: {
        v4: [{ ip_address: "5.6.7.8", type: "public" }],
      },
    });

    inquirer.prompt.mockResolvedValue({ token: "tok123" });

    // First got call: getUserDataScript -> got(url).text()
    mockedGot.mockReturnValueOnce({
      text: jest.fn().mockResolvedValue("#!/bin/bash"),
    });
    // Subsequent got calls: isCodeServerLive -> await got(url, opts) -> { statusCode }
    mockedGot.mockReturnValue({ statusCode: 200 });

    createDroplet.mockResolvedValue(makeDroplet({ id: "42" }));
    getDroplet.mockResolvedValue(activeDroplet);

    await deployDigitalOcean();

    expect(inquirer.prompt).toHaveBeenCalled();
    expect(createDroplet).toHaveBeenCalled();
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining("code-server is live")
    );
  });

  it("propagates TypeError on error due to spinner scoping bug in source", async () => {
    // NOTE: The source has a variable shadowing bug — `let spinner` inside the
    // try block shadows the outer declaration, so the catch block references an
    // uninitialized outer `spinner` and throws TypeError.
    inquirer.prompt.mockResolvedValue({ token: "bad" });
    mockedGot.mockReturnValue({
      text: jest.fn().mockResolvedValue("data"),
    });
    createDroplet.mockRejectedValue(new Error("boom"));

    await expect(deployDigitalOcean()).rejects.toThrow(TypeError);
  });
});
