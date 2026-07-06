import got from "got";
import { createDroplet, getDroplet } from "../../lib/digitalOcean";

jest.mock("got", () => {
  const jsonFn = jest.fn();
  const postFn = jest.fn(() => ({ json: jsonFn }));
  const getFn = Object.assign(
    jest.fn(() => ({ json: jsonFn })),
    {
      post: postFn,
    }
  );
  (getFn as any).__jsonFn = jsonFn;
  (getFn as any).__postFn = postFn;
  return { __esModule: true, default: getFn };
});

const mockedGot = got as unknown as jest.Mock & {
  post: jest.Mock;
  __jsonFn: jest.Mock;
  __postFn: jest.Mock;
};

beforeEach(() => {
  jest.clearAllMocks();
});

describe("createDroplet", () => {
  it("sends a POST to /droplets with correct payload and returns the droplet", async () => {
    const fakeDroplet = {
      id: "123",
      name: "code-server",
      networks: { v4: [] },
      status: "new" as const,
    };
    mockedGot.__jsonFn.mockResolvedValue({ droplet: fakeDroplet });

    const result = await createDroplet({
      token: "test-token",
      userData: "#!/bin/bash\necho hello",
    });

    expect(mockedGot.post).toHaveBeenCalledWith(
      "https://api.digitalocean.com/v2/droplets",
      {
        json: {
          name: "code-server",
          region: "nyc3",
          size: "s-1vcpu-1gb",
          image: "ubuntu-20-10-x64",
          user_data: "#!/bin/bash\necho hello",
        },
        headers: {
          Authorization: "Bearer test-token",
        },
      }
    );
    expect(result).toEqual(fakeDroplet);
  });

  it("propagates errors from the API call", async () => {
    mockedGot.__jsonFn.mockRejectedValue(new Error("API Error"));

    await expect(
      createDroplet({ token: "bad-token", userData: "data" })
    ).rejects.toThrow("API Error");
  });
});

describe("getDroplet", () => {
  it("sends a GET to /droplets/:id with auth header and returns the droplet", async () => {
    const fakeDroplet = {
      id: "456",
      name: "code-server",
      networks: { v4: [{ ip_address: "1.2.3.4", type: "public" as const }] },
      status: "active" as const,
    };
    mockedGot.__jsonFn.mockResolvedValue({ droplet: fakeDroplet });

    const result = await getDroplet({ token: "my-token", id: "456" });

    expect(mockedGot).toHaveBeenCalledWith(
      "https://api.digitalocean.com/v2/droplets/456",
      {
        headers: {
          Authorization: "Bearer my-token",
        },
      }
    );
    expect(result).toEqual(fakeDroplet);
  });

  it("propagates errors from the API call", async () => {
    mockedGot.__jsonFn.mockRejectedValue(new Error("Not Found"));

    await expect(getDroplet({ token: "my-token", id: "999" })).rejects.toThrow(
      "Not Found"
    );
  });
});
