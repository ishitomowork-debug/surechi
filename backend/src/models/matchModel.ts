import mongoose, { Schema, Document } from 'mongoose';

export interface IMatch extends Document {
  user1: mongoose.Types.ObjectId;
  user2: mongoose.Types.ObjectId;
  matchedAt: Date;
  expiresAt: Date;
}

const matchSchema = new Schema<IMatch>({
  user1: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  user2: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  matchedAt: { type: Date, default: Date.now },
  expiresAt: {
    type: Date,
    default: () => new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7日後
  },
});

matchSchema.index({ user1: 1, user2: 1 }, { unique: true });

const Match = mongoose.model<IMatch>('Match', matchSchema);
export default Match;
