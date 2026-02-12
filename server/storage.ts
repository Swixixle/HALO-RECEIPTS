import { receipts, interpretations, researchRecords, llmObservations, exportJobs, type Receipt, type InsertReceipt, type Interpretation, type InsertInterpretation, type ExportJob, type InsertExportJob } from "@shared/schema";
import { db } from "./db";
import { eq, and, gte, lte, like, or, isNull, desc, asc, sql, count } from "drizzle-orm";

// Research record insert type
export interface InsertResearchRecord {
  researchId: string;
  datasetVersion: string;
  captureDateBucket: string;
  verificationDateBucket: string;
  platformCategory: string;
  verificationOutcome: string;
  signatureOutcome: string;
  chainOutcome: string;
  structuralStats: string;
  anomalyIndicators: string;
  riskCategories: string;
  piiPresence: string;
  killSwitchEngaged: number;
  interpretationBucket: string;
  consentScope: string;
  createdAtBucket: string;
}

export type ResearchRecordRow = typeof researchRecords.$inferSelect;

// P6: LLM Observation types (SENSOR MODE - separate from verification)
export interface InsertLlmObservation {
  observationId: string;
  receiptId: string;
  modelId: string;
  observationType: string;
  basedOn: string;
  content: string;
  confidenceStatement: string;
  limitations: string; // JSON array
  createdAt: string;
}

export type LlmObservationRow = typeof llmObservations.$inferSelect;

export interface ResearchExportFilters {
  startDate?: string;
  endDate?: string;
  platformCategory?: string;
  verificationOutcome?: string;
}

export interface PagedReceiptsParams {
  page: number;
  pageSize: number;
  status?: string;
  q?: string;
  hasForensics?: boolean;
  killSwitch?: boolean;
  order?: "asc" | "desc";
  beforeDate?: string;
}

export interface PagedReceiptsResult {
  items: Receipt[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export interface IStorage {
  getReceipt(receiptId: string): Promise<Receipt | undefined>;
  getReceiptById(id: string): Promise<Receipt | undefined>;
  getAllReceipts(): Promise<Receipt[]>;
  getPagedReceipts(params: PagedReceiptsParams): Promise<PagedReceiptsResult>;
  createReceipt(receipt: InsertReceipt): Promise<{ receipt: Receipt; alreadyExists: boolean }>;
  updateReceiptKillSwitch(receiptId: string): Promise<Receipt | undefined>;
  getInterpretations(receiptId: string): Promise<Interpretation[]>;
  createInterpretation(interpretation: InsertInterpretation): Promise<Interpretation>;
  createResearchRecord(record: InsertResearchRecord): Promise<ResearchRecordRow>;
  getResearchRecords(filters?: ResearchExportFilters): Promise<ResearchRecordRow[]>;
  createLlmObservation(observation: InsertLlmObservation): Promise<LlmObservationRow>;
  getLlmObservations(receiptId: string): Promise<LlmObservationRow[]>;
  createExportJob(job: InsertExportJob): Promise<ExportJob>;
  getExportJob(exportId: string): Promise<ExportJob | undefined>;
  updateExportJob(exportId: string, updates: Partial<Pick<ExportJob, "status" | "completed" | "total" | "filePath" | "errorMessage">>): Promise<ExportJob | undefined>;
}

export class DatabaseStorage implements IStorage {
  async getReceipt(receiptId: string): Promise<Receipt | undefined> {
    const result = await db.select().from(receipts).where(eq(receipts.receiptId, receiptId)).limit(1);
    return result[0];
  }

  async getReceiptById(id: string): Promise<Receipt | undefined> {
    const result = await db.select().from(receipts).where(eq(receipts.id, id)).limit(1);
    return result[0];
  }

  async getAllReceipts(): Promise<Receipt[]> {
    return db.select().from(receipts).orderBy(receipts.createdAt);
  }

  async getPagedReceipts(params: PagedReceiptsParams): Promise<PagedReceiptsResult> {
    const conditions = [];

    if (params.status) {
      conditions.push(eq(receipts.verificationStatus, params.status));
    }
    if (params.q) {
      conditions.push(like(receipts.receiptId, `%${params.q}%`));
    }
    if (params.hasForensics === true) {
      conditions.push(sql`${receipts.forensicsJson} IS NOT NULL AND ${receipts.forensicsJson} != ''`);
    } else if (params.hasForensics === false) {
      conditions.push(or(isNull(receipts.forensicsJson), eq(receipts.forensicsJson, "")));
    }
    if (params.killSwitch === true) {
      conditions.push(eq(receipts.hindsightKillSwitch, 1));
    } else if (params.killSwitch === false) {
      conditions.push(eq(receipts.hindsightKillSwitch, 0));
    }
    if (params.beforeDate) {
      conditions.push(sql`${receipts.createdAt} <= ${params.beforeDate}`);
    }

    const whereClause = conditions.length > 0 ? and(...conditions) : undefined;

    const orderDir = params.order === "asc" ? asc : desc;
    const orderBy = [orderDir(receipts.createdAt), desc(receipts.receiptId)];

    const offset = (params.page - 1) * params.pageSize;

    const [items, totalResult] = await Promise.all([
      whereClause
        ? db.select().from(receipts).where(whereClause).orderBy(...orderBy).limit(params.pageSize).offset(offset)
        : db.select().from(receipts).orderBy(...orderBy).limit(params.pageSize).offset(offset),
      whereClause
        ? db.select({ count: count() }).from(receipts).where(whereClause)
        : db.select({ count: count() }).from(receipts),
    ]);

    const total = totalResult[0]?.count ?? 0;
    const totalPages = Math.max(1, Math.ceil(total / params.pageSize));
    const clampedPage = Math.max(1, Math.min(params.page, totalPages));

    return {
      items,
      total,
      page: clampedPage,
      pageSize: params.pageSize,
      totalPages,
    };
  }

  async createReceipt(receipt: InsertReceipt): Promise<{ receipt: Receipt; alreadyExists: boolean }> {
    const existing = await this.getReceipt(receipt.receiptId);
    if (existing) {
      if (existing.immutableLock === 1) {
        return { receipt: existing, alreadyExists: true };
      }
      const result = await db
        .update(receipts)
        .set(receipt)
        .where(eq(receipts.receiptId, receipt.receiptId))
        .returning();
      return { receipt: result[0], alreadyExists: false };
    }
    
    const result = await db.insert(receipts).values(receipt).returning();
    return { receipt: result[0], alreadyExists: false };
  }

  async updateReceiptKillSwitch(receiptId: string): Promise<Receipt | undefined> {
    const receipt = await this.getReceipt(receiptId);
    if (!receipt) return undefined;
    
    if (receipt.hindsightKillSwitch === 1) {
      return receipt;
    }
    
    const result = await db
      .update(receipts)
      .set({ hindsightKillSwitch: 1 })
      .where(eq(receipts.receiptId, receiptId))
      .returning();
    return result[0];
  }

  async getInterpretations(receiptId: string): Promise<Interpretation[]> {
    return db.select().from(interpretations).where(eq(interpretations.receiptId, receiptId)).orderBy(interpretations.createdAt);
  }

  async createInterpretation(interpretation: InsertInterpretation): Promise<Interpretation> {
    const result = await db.insert(interpretations).values(interpretation).returning();
    return result[0];
  }

  // P5: Research records
  async createResearchRecord(record: InsertResearchRecord): Promise<ResearchRecordRow> {
    const result = await db.insert(researchRecords).values(record).returning();
    return result[0];
  }

  async getResearchRecords(filters?: ResearchExportFilters): Promise<ResearchRecordRow[]> {
    const conditions = [];
    
    if (filters?.startDate) {
      conditions.push(gte(researchRecords.captureDateBucket, filters.startDate));
    }
    if (filters?.endDate) {
      conditions.push(lte(researchRecords.captureDateBucket, filters.endDate));
    }
    if (filters?.platformCategory) {
      conditions.push(eq(researchRecords.platformCategory, filters.platformCategory));
    }
    if (filters?.verificationOutcome) {
      conditions.push(eq(researchRecords.verificationOutcome, filters.verificationOutcome));
    }
    
    if (conditions.length === 0) {
      return db.select().from(researchRecords).orderBy(researchRecords.captureDateBucket);
    }
    
    return db.select().from(researchRecords)
      .where(and(...conditions))
      .orderBy(researchRecords.captureDateBucket);
  }

  // P6: LLM Observations (SENSOR MODE - separate from verification)
  async createLlmObservation(observation: InsertLlmObservation): Promise<LlmObservationRow> {
    const result = await db.insert(llmObservations).values(observation).returning();
    return result[0];
  }

  async getLlmObservations(receiptId: string): Promise<LlmObservationRow[]> {
    return db.select().from(llmObservations)
      .where(eq(llmObservations.receiptId, receiptId))
      .orderBy(llmObservations.createdAt);
  }

  async createExportJob(job: InsertExportJob): Promise<ExportJob> {
    const result = await db.insert(exportJobs).values(job).returning();
    return result[0];
  }

  async getExportJob(exportId: string): Promise<ExportJob | undefined> {
    const result = await db.select().from(exportJobs).where(eq(exportJobs.exportId, exportId)).limit(1);
    return result[0];
  }

  async updateExportJob(exportId: string, updates: Partial<Pick<ExportJob, "status" | "completed" | "total" | "filePath" | "errorMessage">>): Promise<ExportJob | undefined> {
    const setObj: Record<string, unknown> = {};
    if (updates.status !== undefined) setObj.status = updates.status;
    if (updates.completed !== undefined) setObj.completed = updates.completed;
    if (updates.total !== undefined) setObj.total = updates.total;
    if (updates.filePath !== undefined) setObj.filePath = updates.filePath;
    if (updates.errorMessage !== undefined) setObj.errorMessage = updates.errorMessage;

    const result = await db.update(exportJobs)
      .set(setObj)
      .where(eq(exportJobs.exportId, exportId))
      .returning();
    return result[0];
  }
}

export const storage = new DatabaseStorage();
