import { authenticateRequest } from "./auth";
import { checkAddresses } from "./sanctions";
import {
  Env,
  SanctionsCheckRequest,
  SanctionsCheckResponse,
  ErrorResponse,
} from "./types";

/**
 * Tacit Sanctions Screening API
 *
 * POST /sanctions/check
 * - Auth: Bearer <api_key> (key stored in Vault DON, retrieved inside TEE)
 * - Body: { addresses: string[], list?: string }
 * - Response: { allClear: boolean, results: [...], timestamp: string }
 *
 * GET /health
 * - No auth required
 * - Response: { status: "ok", service: "tacit-sanctions-api" }
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

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // Health check (no auth required)
    if (url.pathname === "/health" && request.method === "GET") {
      let kvPopulated = false;
      try {
        const sampleKey = await env.SANCTIONS_KV.get(
          "addr:0x8589427373d6d84e98730d7795d8f6f8731fda16"
        );
        kvPopulated = sampleKey !== null;
      } catch {
        // KV not bound — running without KV namespace
      }

      return Response.json(
        {
          status: "ok",
          service: "tacit-sanctions-api",
          timestamp: new Date().toISOString(),
          dataSource: kvPopulated
            ? "OFAC_SDN_KV + hardcoded"
            : "hardcoded only",
          kvPopulated,
        },
        { headers: corsHeaders }
      );
    }

    // Main endpoint: POST /sanctions/check
    if (url.pathname === "/sanctions/check" && request.method === "POST") {
      // Authenticate
      const authError = authenticateRequest(request, env);
      if (authError) {
        return Response.json(authError, {
          status: 401,
          headers: corsHeaders,
        });
      }

      try {
        const body = (await request.json()) as SanctionsCheckRequest;

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

        const { allClear, results } = await checkAddresses(
          body.addresses,
          env
        );

        const response: SanctionsCheckResponse = {
          allClear,
          results,
          timestamp: new Date().toISOString(),
          list: body.list || "OFAC_SDN",
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

    // 404 for all other routes
    return Response.json(
      { error: "Not found", code: "NOT_FOUND" } as ErrorResponse,
      { status: 404, headers: corsHeaders }
    );
  },
};
