import mongoose, { Schema, Document } from 'mongoose';
import bcryptjs from 'bcryptjs';

export interface IUser extends Document {
  name: string;
  email: string;
  password: string;
  age: number;
  bio?: string;
  interests?: string[];
  avatar?: string;
  deviceToken?: string;
  lastActiveAt?: Date;
  coins: number;
  dailyLikeCount: number;
  dailyLikeResetAt?: Date;
  location?: {
    type: 'Point';
    coordinates: [number, number]; // [longitude, latitude]
  };
  createdAt: Date;
  updatedAt: Date;
  comparePassword(enteredPassword: string): Promise<boolean>;
}

const userSchema = new Schema<IUser>(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, match: /.+\@.+\..+/ },
    password: { type: String, required: true, minlength: 6, select: false },
    age: { type: Number, required: true, min: 18 },
    bio: { type: String, trim: true, maxlength: 500 },
    interests: { type: [String], default: [] },
    avatar: { type: String },
    deviceToken: { type: String },
    lastActiveAt: { type: Date },
    coins: { type: Number, default: 10 }, // 新規登録で10コイン付与
    dailyLikeCount: { type: Number, default: 0 },
    dailyLikeResetAt: { type: Date },
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] },
    },
  },
  { timestamps: true }
);

userSchema.index({ location: '2dsphere' });

userSchema.pre<IUser>('save', async function (next) {
  if (!this.isModified('password')) return next();
  try {
    const salt = await bcryptjs.genSalt(10);
    this.password = await bcryptjs.hash(this.password, salt);
    next();
  } catch (error) {
    next(error as Error);
  }
});

userSchema.methods.comparePassword = async function (enteredPassword: string): Promise<boolean> {
  return await bcryptjs.compare(enteredPassword, this.password);
};

const User = mongoose.model<IUser>('User', userSchema);
export default User;
