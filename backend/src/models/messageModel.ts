import mongoose, { Schema, Document } from 'mongoose';

export interface IMessage extends Document {
  matchId: mongoose.Types.ObjectId;
  senderId: mongoose.Types.ObjectId;
  content: string;
  read: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const messageSchema = new Schema<IMessage>(
  {
    matchId: { type: Schema.Types.ObjectId, ref: 'Match', required: true },
    senderId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    content: { type: String, required: true, maxlength: 1000, trim: true },
    read: { type: Boolean, default: false },
  },
  { timestamps: true }
);

messageSchema.index({ matchId: 1, createdAt: 1 });

const Message = mongoose.model<IMessage>('Message', messageSchema);
export default Message;
