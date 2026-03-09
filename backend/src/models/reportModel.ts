import mongoose, { Schema, Document } from 'mongoose';

export interface IReport extends Document {
  reporter: mongoose.Types.ObjectId;
  reported: mongoose.Types.ObjectId;
  reason: string;
  createdAt: Date;
}

const reportSchema = new Schema<IReport>(
  {
    reporter: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reported: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reason: { type: String, required: true, maxlength: 200 },
  },
  { timestamps: true }
);

reportSchema.index({ reporter: 1, reported: 1 });

export default mongoose.model<IReport>('Report', reportSchema);
