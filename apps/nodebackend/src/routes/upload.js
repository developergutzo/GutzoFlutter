import express from 'express';
import multer from 'multer';
import { bucket } from '../config/gcp-storage.js';
import { asyncHandler, successResponse, ApiError } from '../middleware/errorHandler.js';
import path from 'path';

const router = express.Router();

// Configure Multer (Memory Storage)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new ApiError(400, 'Only image files are allowed!'), false);
    }
  },
});

// ============================================
// UPLOAD PRODUCT IMAGE
// POST /api/upload/product-image
// ============================================
router.post('/product-image', upload.single('file'), asyncHandler(async (req, res) => {
  if (!req.file) {
    throw new ApiError(400, 'No file uploaded');
  }

  const { vendorId, productId } = req.body;

  if (!vendorId || !productId) {
    throw new ApiError(400, 'vendorId and productId are required');
  }

  // File path format: vendors/{vendorId}/{productId}/{filename}
  // We'll use the original extension but maybe normalize the name
  const ext = path.extname(req.file.originalname);
  const fileName = `vendors/${vendorId}/${productId}/${Date.now()}${ext}`;
  
  const blob = bucket.file(fileName);
  const blobStream = blob.createWriteStream({
    resumable: false,
    contentType: req.file.mimetype,
  });

  blobStream.on('error', (err) => {
    console.error('GCP Upload Error:', err);
    // Cannot throw inside stream event, so we must handle response manually if headers not sent
    // But since we are inside asyncHandler, we might need a promise wrapper if we strictly used async/await.
    // However, for streams, we often wrap in a promise.
  });

  // Wrap stream in a promise to await it
  const publicUrl = await new Promise((resolve, reject) => {
    blobStream.on('finish', () => {
      // The public URL can be constructed directly
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${blob.name}`;
      resolve(publicUrl);
    })
    .on('error', (err) => {
      reject(err);
    });
    
    blobStream.end(req.file.buffer);
  });

  // Depending on bucket settings, we might need to make it public explicitly
  // await blob.makePublic(); // Valid if bucket is not using Uniform Bucket Level Access

  successResponse(res, { url: publicUrl }, 'Image uploaded successfully');
}));

export default router;
