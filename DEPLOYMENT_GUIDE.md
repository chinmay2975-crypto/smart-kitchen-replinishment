# ============================================================
# Smart Kitchen - Google Cloud Run Deployment Guide
# ============================================================

## Last Updated
- Fixed CORS configuration for Firebase hosting
- Added device_readings table to database schema

## Prerequisites
- Google Cloud SDK installed and configured
- Project ID: smart-kitchen-309488529038 (or your actual project ID)
- GitHub repository connected to Google Cloud
- Database (Supabase) already set up

---

## PART 1: Initial Deployment (One-Time Setup)

### Step 1: Enable Required APIs
```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### Step 2: Set Your Project
```bash
gcloud config set project YOUR_PROJECT_ID
```

### Step 3: Deploy Manually (First Time)
```bash
# Build and deploy in one command
gcloud run deploy smart-kitchen-api \
  --source . \
  --region asia-south1 \
  --platform managed \
  --allow-unauthenticated \
  --port 8000 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 1 \
  --max-instances 10 \
  --set-env-vars DATABASE_URL=postgresql+asyncpg://postgres:Chinmay2005%@db.eqjianefzeaighbjegye.supabase.co:6543/postgres?ssl=require,SUPABASE_URL=https://eqjianefzeaighbjegye.supabase.co,SECRET_KEY=d85669c6c3e74554476c5ec4d4407ae9cba3b963e8e8d138ea59c22abdbc2e7c,SERVER_TOKEN=smart_kitchen_server_token_2024,ENABLE_SIMULATION=false,EVALUATION_INTERVAL_SECONDS=30,TELEMETRY_INTERVAL_SECONDS=10
```

**Note**: This will take 3-5 minutes for the first deployment.

---

## PART 2: Automated Deployment Setup (Recommended)

### Step 1: Create Cloud Build Trigger

1. **Go to Google Cloud Console**:
   - Navigate to: https://console.cloud.google.com/cloud-build/triggers
   - Or search "Cloud Build" in the Google Cloud Console

2. **Click "Create Trigger"**

3. **Configure Trigger Settings**:
   ```
   Name: smart-kitchen-deploy
   Description: Auto-deploy to Cloud Run on push to main
   Event: Push to a branch
   Repository: Select your GitHub repository
   Branch: main (or master)
   ```

4. **Build Configuration**:
   - Select: "Cloud Build configuration file (yaml or json)"
   - Location: `cloudbuild.yaml` (in root of your repo)

5. **Click "Create"**

### Step 2: Test the Automation

```bash
# Make a small change and push to trigger the deployment
git add .
git commit -m "test: trigger automated deployment"
git push origin main
```

### Step 3: Monitor Deployment

1. Go to Cloud Build → History
2. You'll see the build running
3. Click on the build to see detailed logs
4. Once complete, your app will be live at the Cloud Run URL

---

## PART 3: Verify Deployment

### Check Service Status
```bash
gcloud run services describe smart-kitchen-api --region asia-south1
```

### Test the API
```bash
# Get the service URL
SERVICE_URL=$(gcloud run services describe smart-kitchen-api --region asia-south1 --format='value(status.url)')

# Test health endpoint
curl $SERVICE_URL/health

# Expected response: {"status":"healthy"}
```

### View Logs
```bash
# Stream logs in real-time
gcloud run services logs read smart-kitchen-api --region asia-south1 --follow

# Or view recent logs
gcloud run services logs read smart-kitchen-api --region asia-south1 --limit=50
```

---

## PART 4: Update Frontend API URL

After deployment, update your frontend to point to the new backend URL:

### Option A: Update api.js (if using local HTML files)
```javascript
// In frontend/js/api.js, line 4:
const API_BASE = 'https://YOUR_CLOUD_RUN_URL';
```

### Option B: Deploy Frontend to Firebase Hosting (Recommended)

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

2. **Initialize Firebase**:
   ```bash
   firebase init hosting
   # Select your project
   # Set public directory: frontend
   # Configure as single-page app: No
   # Don't overwrite index.html
   ```

3. **Deploy Frontend**:
   ```bash
   firebase deploy --only hosting
   ```

4. **Update CORS** (if needed):
   - Your backend already has `allow_origins=["*"]` so it should work

---

## PART 5: Useful Commands

### View Current Deployment
```bash
gcloud run services list
```

### Rollback to Previous Version
```bash
# List revisions
gcloud run revisions list --service=smart-kitchen-api --region=asia-south1

# Route traffic to specific revision
gcloud run services update-traffic smart-kitchen-api \
  --region asia-south1 \
  --to-revisions REVISION_NAME=100
```

### Manual Trigger of Cloud Build
```bash
gcloud builds submit --config cloudbuild.yaml
```

### View Build History
```bash
gcloud builds list
```

### Delete Old Images (to save storage)
```bash
# List images
gcloud container images list

# Delete old images (keep last 5)
gcloud container images list-tags gcr.io/YOUR_PROJECT_ID/smart-kitchen-api \
  --filter='tags~^v' \
  --format='get(digest)' | tail -n +6 | xargs -I {} gcloud container images delete gcr.io/YOUR_PROJECT_ID/smart-kitchen-api@{} --quiet
```

---

## PART 6: Environment Variables Reference

Current environment variables set in Cloud Run:
```
DATABASE_URL=postgresql+asyncpg://postgres:Chinmay2005%@db.eqjianefzeaighbjegye.supabase.co:6543/postgres?ssl=require
SUPABASE_URL=https://eqjianefzeaighbjegye.supabase.co
SECRET_KEY=d85669c6c3e74554476c5ec4d4407ae9cba3b963e8e8d138ea59c22abdbc2e7c
SERVER_TOKEN=smart_kitchen_server_token_2024
ENABLE_SIMULATION=false
EVALUATION_INTERVAL_SECONDS=30
TELEMETRY_INTERVAL_SECONDS=10
PORT=8000 (automatically set by Cloud Run)
```

To update environment variables:
```bash
gcloud run services update smart-kitchen-api \
  --region asia-south1 \
  --set-env-vars KEY=VALUE,KEY2=VALUE2
```

---

## Troubleshooting

### Build Fails
```bash
# Check build logs
gcloud builds log BUILD_ID

# Common issues:
# - Missing dependencies in requirements.txt
# - Dockerfile errors
# - Port mismatch (should be 8000)
```

### Service Won't Start
```bash
# Check logs
gcloud run services logs read smart-kitchen-api --region asia-south1 --limit=100

# Common issues:
# - Database connection failed (check DATABASE_URL)
# - Port not configured correctly
# - Memory limits too low
```

### Database Connection Issues
- Verify Supabase is running
- Check DATABASE_URL format
- Ensure SSL is enabled (ssl=require)
- Test connection locally first

---

## Cost Optimization

### Current Configuration (Free Tier Eligible)
- Memory: 512Mi
- CPU: 1
- Min instances: 1 (keeps 1 warm)
- Max instances: 10

### To Reduce Costs
```bash
# Set min instances to 0 (cold starts will occur)
gcloud run services update smart-kitchen-api \
  --region asia-south1 \
  --min-instances=0

# Reduce memory (if not needed)
gcloud run services update smart-kitchen-api \
  --region asia-south1 \
  --memory=256Mi
```

**Note**: Cloud Run has a generous free tier:
- 2 million requests/month
- 360,000 vCPU-seconds/month
- 180,000 GiB-seconds/month

---

## Next Steps

1. ✅ Complete Part 1 (Initial Deployment)
2. ✅ Complete Part 2 (Automated Deployment Setup)
3. ✅ Test the device claiming feature
4. ✅ Deploy frontend to Firebase Hosting (optional)
5. ✅ Set up monitoring and alerts (optional)

---

## Support

If you encounter issues:
1. Check Cloud Build logs: https://console.cloud.google.com/cloud-build/builds
2. Check Cloud Run logs: `gcloud run services logs read smart-kitchen-api --region asia-south1`
3. Verify environment variables are set correctly
4. Test database connection from Cloud Shell