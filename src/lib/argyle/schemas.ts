import { z } from "zod";

/**
 * Query params for GET /paystubs
 * Docs: https://docs.argyle.com/api-reference/paystubs
 */
export const ArgylePaystubsQuerySchema = z.object({
  user: z.uuid().optional(),
  account: z.uuid().optional(),
  from_start_date: z.string().optional(),
  to_start_date: z.string().optional(),
  limit: z.number().optional(),
  cursor: z.string().optional(),
});

/**
 * Argyle paginated response wrapper
 * All list endpoints return { results: [...], next: string | null, previous: string | null }
 * Docs: https://docs.argyle.com/api-reference/pagination
 */
export const ArgylePaginatedResponseSchema = <T extends z.ZodType>(schema: T) =>
  z.object({
    results: z.array(schema),
    next: z.string().nullable(),
    previous: z.string().nullable(),
  });

/**
 * Argyle Paystub
 * Docs: https://docs.argyle.com/api-reference/paystubs
 *
 * We use these fields for income calculations and storage.
 * API returns many more fields (deduction_list, tax_list, filing_status, etc.)
 */
const ArgylePaystubPeriodSchema = z.object({
  start_date: z.string(),
  end_date: z.string(),
});

export const ArgylePaystubSchema = z.object({
  id: z.uuid(),
  account: z.uuid(),
  user: z.uuid(),
  // Monetary amounts are decimal strings, e.g. "1290.10"
  gross_pay: z.string(),
  net_pay: z.string(),
  deductions: z.string(),
  taxes: z.string(),
  hours: z.string().nullable(),
  currency: z.string(),
  paystub_period: ArgylePaystubPeriodSchema,
  paystub_date: z.string(),
  employer: z.string(),
});

export type ArgylePaystub = z.infer<typeof ArgylePaystubSchema>;
