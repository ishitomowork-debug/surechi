import mongoose, { Schema, Document } from 'mongoose';

const REPORT_REASONS = [
  'sexual_harassment',
  'fraud',
  'child_abuse',
  'violence',
  'hate_speech',
  'spam',
  'fake_profile',
  'other',
] as const;

export type ReportReason = (typeof REPORT_REASONS)[number];

export interface IReport extends Document {
  reporter: mongoose.Types.ObjectId;
  reported: mongoose.Types.ObjectId;
  reason: ReportReason;
  reasonText?: string;
  createdAt: Date;
}

const reportSchema = new Schema<IReport>(
  {
    reporter: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reported: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reason: {
      type: String,
      required: true,
      enum: REPORT_REASONS,
    },
    reasonText: { type: String, maxlength: 500 },
  },
  { timestamps: true }
);

reportSchema.index({ reporter: 1, reported: 1 });

export default mongoose.model<IReport>('Report', reportSchema);
