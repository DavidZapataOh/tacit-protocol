import { authenticateRequest } from "./auth";
import { verifyAddresses, seedWallet } from "./kyc";
import {
  Env,
  KYCVerifyRequest,
  KYCVerifyResponse,
  KYCRecord,
  ErrorResponse,
} from "./types";

/**
 * Tacit KYC/Accreditation Verification API
 *
 * POST /kyc/verify
 * - Auth: Bearer <api_key>
 * - Body: { addresses: string[], requiredLevel?: string }
 * - Response: { allVerified: boolean, results: [...], timestamp: string }
 *
 * POST /kyc/seed (admin — populate demo wallets)
 * - Auth: Bearer <api_key>
 * - Body: { address: string, level: string, expiresAt?: string }
 *
 * GET /health
 * - No auth required
 */
export default {
  async fetch(
    request: Request,
    env: Env,
    _ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);

    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Health check
    if (url.pathname === "/health" && request.method === "GET") {
      return Response.json(
        {
          status: "ok",
          service: "tacit-kyc-api",
          timestamp: new Date().toISOString(),
        },
        { headers: corsHeaders }
      );
    }

    // Main endpoint: POST /kyc/verify
    if (url.pathname === "/kyc/verify" && request.method === "POST") {
      const authError = authenticateRequest(request, env);
      if (authError) {
        return Response.json(authError, {
          status: 401,
          headers: corsHeaders,
        });
      }

      try {
        const body = (await request.json()) as KYCVerifyRequest;

        if (!body.addresses || !Array.isArray(body.addresses)) {
          return Response.json(
            {
              error: "Missing or invalid 'addresses' array",
              code: "INVALID_REQUEST",
            } as ErrorResponse,
            { status: 400, headers: corsHeaders }
          );
        }

        if (body.addresses.length === 0) {
          return Response.json(
            {
              error: "Addresses array cannot be empty",
              code: "INVALID_REQUEST",
            } as ErrorResponse,
            { status: 400, headers: corsHeaders }
          );
        }

        if (body.addresses.length > 10) {
          return Response.json(
            {
              error: "Maximum 10 addresses per request",
              code: "RATE_LIMIT",
            } as ErrorResponse,
            { status: 429, headers: corsHeaders }
          );
        }

        const requiredLevel = body.requiredLevel || "basic";
        const { allVerified, results } = await verifyAddresses(
          body.addresses,
          requiredLevel,
          env
        );

        const response: KYCVerifyResponse = {
          allVerified,
          results,
          timestamp: new Date().toISOString(),
          requiredLevel,
        };

        return Response.json(response, {
          status: 200,
          headers: corsHeaders,
        });
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "Internal server error";
        const isValidationError =
          message.startsWith("Invalid Ethereum address");
        return Response.json(
          {
            error: message,
            code: isValidationError ? "INVALID_REQUEST" : "INTERNAL_ERROR",
          } as ErrorResponse,
          { status: isValidationError ? 400 : 500, headers: corsHeaders }
        );
      }
    }

    // Admin endpoint: POST /kyc/seed (add wallets for demo)
    if (url.pathname === "/kyc/seed" && request.method === "POST") {
      const authError = authenticateRequest(request, env);
      if (authError) {
        return Response.json(authError, {
          status: 401,
          headers: corsHeaders,
        });
      }

      try {
        const body = (await request.json()) as {
          address: string;
          level: string;
          expiresAt?: string;
        };

        if (!body.address || !body.level) {
          return Response.json(
            {
              error: "Missing 'address' or 'level'",
              code: "INVALID_REQUEST",
            } as ErrorResponse,
            { status: 400, headers: corsHeaders }
          );
        }

        const record: KYCRecord = {
          level: body.level as KYCRecord["level"],
          verifiedAt: new Date().toISOString(),
          expiresAt:
            body.expiresAt ||
            new Date(
              Date.now() + 365 * 24 * 60 * 60 * 1000
            ).toISOString(),
        };

        await seedWallet(body.address, record, env);

        return Response.json(
          { success: true, address: body.address.toLowerCase(), record },
          { status: 200, headers: corsHeaders }
        );
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "Internal server error";
        return Response.json(
          { error: message, code: "INTERNAL_ERROR" } as ErrorResponse,
          { status: 500, headers: corsHeaders }
        );
      }
    }

    return Response.json(
      { error: "Not found", code: "NOT_FOUND" } as ErrorResponse,
      { status: 404, headers: corsHeaders }
    );
  },
};
