import mongoose, { Document, Schema } from 'mongoose';

export interface IEncounter extends Document {
  user1: mongoose.Types.ObjectId;
  user2: mongoose.Types.ObjectId;
  encounteredAt: Date;
}

const encounterSchema = new Schema<IEncounter>({
  user1: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  user2: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  encounteredAt: { type: Date, default: Date.now, expires: 600 }, // 10分でTTL削除
});

// 同じペアの重複を防ぐ
encounterSchema.index({ user1: 1, user2: 1 }, { unique: true });

export default mongoose.model<IEncounter>('Encounter', encounterSchema);
