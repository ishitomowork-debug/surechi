import mongoose, { Schema, Document } from 'mongoose';

export interface IProcessedTransaction extends Document {
  transactionId: string;
  userId: mongoose.Types.ObjectId;
  productId: string;
  coins: number;
  processedAt: Date;
}

const processedTransactionSchema = new Schema<IProcessedTransaction>({
  transactionId: { type: String, required: true, unique: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  productId: { type: String },
  coins: { type: Number },
  processedAt: { type: Date, default: Date.now },
});

// transactionId での検索を高速化
processedTransactionSchema.index({ transactionId: 1 });
// ユーザーごとの購入履歴取得用
processedTransactionSchema.index({ userId: 1, processedAt: -1 });

const ProcessedTransaction = mongoose.model<IProcessedTransaction>(
  'ProcessedTransaction',
  processedTransactionSchema
);

export default ProcessedTransaction;
