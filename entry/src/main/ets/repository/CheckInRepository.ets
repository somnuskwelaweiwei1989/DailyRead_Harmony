import relationalStore from '@ohos.data.relationalStore';
import { CheckInRecord } from '../model/CheckInRecord';
import { AppDatabase, TableNames } from '../database/AppDatabase';

export class CheckInRepository {
  private static instance: CheckInRepository | null = null;

  static getInstance(): CheckInRepository {
    if (!CheckInRepository.instance) {
      CheckInRepository.instance = new CheckInRepository();
    }
    return CheckInRepository.instance;
  }

  async getAllCheckInRecords(): Promise<CheckInRecord[]> {
    const db = AppDatabase.getInstance().getDb();
    const records: CheckInRecord[] = [];
    try {
      const predicates = new relationalStore.RdbPredicates(TableNames.CHECKINS);
      const result: relationalStore.ResultSet = await db.query(predicates);
      const colId: number = result.getColumnIndex('id');
      const colArticleId: number = result.getColumnIndex('articleId');
      const colCheckInDate: number = result.getColumnIndex('checkInDate');
      const colCheckInTime: number = result.getColumnIndex('checkInTime');
      const colLastModified: number = result.getColumnIndex('lastModified');
      while (result.goToNextRow()) {
        const record: CheckInRecord = new CheckInRecord();
        record.id = result.getLong(colId);
        record.articleId = result.getLong(colArticleId);
        record.checkInDate = result.getString(colCheckInDate);
        record.checkInTime = result.getString(colCheckInTime);
        record.lastModified = result.getString(colLastModified);
        records.push(record);
      }
      result.close();
    } catch (e) {
      console.error('getAllCheckInRecords error:', JSON.stringify(e));
    }
    return records;
  }

  async insertCheckInRecord(record: CheckInRecord): Promise<number> {
    const db = AppDatabase.getInstance().getDb();
    const valueBucket: relationalStore.ValuesBucket = {
      articleId: record.articleId,
      checkInDate: record.checkInDate,
      checkInTime: record.checkInTime,
      lastModified: record.lastModified
    };
    return await db.insert(TableNames.CHECKINS, valueBucket);
  }

  async deleteAllCheckInRecords(): Promise<number> {
    const db = AppDatabase.getInstance().getDb();
    const predicates = new relationalStore.RdbPredicates(TableNames.CHECKINS);
    return await db.delete(predicates);
  }
}
