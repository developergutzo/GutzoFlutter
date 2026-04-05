import { Storage } from '@google-cloud/storage';
import path from 'path';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';

dotenv.config();

// Initialize storage
// We expect GOOGLE_APPLICATION_CREDENTIALS to be set in .env or the key file to be present
// For now, we'll try to use a standard file name if env is not set
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const keyFilePath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

const storage = new Storage({
  keyFilename: keyFilePath,
  projectId: process.env.GCP_PROJECT_ID, // Optional if key file has it
});

const bucketName = process.env.GCP_BUCKET_NAME;
const bucket = storage.bucket(bucketName);

export { storage, bucket, bucketName };
