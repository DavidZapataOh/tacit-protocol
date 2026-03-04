import { Env, ErrorResponse } from "./types";

/**
 * Validate the API key from the Authorization header.
 * The CRE workflow sends this as: Authorization: Bearer <api_key>
 * The key is retrieved from Vault DON inside the TEE and never touches the blockchain.
 */
export function authenticateRequest(
  request: Request,
  env: Env
): ErrorResponse | null {
  const authHeader = request.headers.get("Authorization");

  if (!authHeader) {
    return { error: "Missing Authorization header", code: "AUTH_MISSING" };
  }

  if (!authHeader.startsWith("Bearer ")) {
    return {
      error: "Invalid Authorization format. Use: Bearer <api_key>",
      code: "AUTH_FORMAT",
    };
  }

  const providedKey = authHeader.slice(7);

  // Constant-time comparison to prevent timing attacks
  if (providedKey.length !== env.SANCTIONS_API_KEY.length) {
    return { error: "Invalid API key", code: "AUTH_INVALID" };
  }

  let mismatch = 0;
  for (let i = 0; i < providedKey.length; i++) {
    mismatch |= providedKey.charCodeAt(i) ^ env.SANCTIONS_API_KEY.charCodeAt(i);
  }

  if (mismatch !== 0) {
    return { error: "Invalid API key", code: "AUTH_INVALID" };
  }

  return null;
}
