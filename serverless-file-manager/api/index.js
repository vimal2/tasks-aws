const { S3Client, ListObjectsV2Command, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
const { CloudWatchLogsClient, GetLogEventsCommand, DescribeLogStreamsCommand } = require('@aws-sdk/client-cloudwatch-logs');

const s3Client = new S3Client({});
const logsClient = new CloudWatchLogsClient({});

const BUCKET_NAME = process.env.BUCKET_NAME || 'lambda-s3-demo-bucket-127246139738';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
  'Content-Type': 'application/json'
};

const response = (statusCode, body) => ({
  statusCode,
  headers: CORS_HEADERS,
  body: JSON.stringify(body)
});

// Helper to get S3 prefix based on taskId
const getPrefix = (taskId) => {
  return taskId ? `tasks/${taskId}/` : 'uploads/';
};

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  // Support both API Gateway REST API (v1) and HTTP API (v2) event formats
  const httpMethod = event.httpMethod || event.requestContext?.http?.method || '';
  let path = event.path || event.rawPath || event.requestContext?.http?.path || '';
  const queryStringParameters = event.queryStringParameters || {};

  // Normalize path - remove stage prefix if present (e.g., /prod/upload -> /upload)
  path = '/' + path.split('/').filter(p => p && p !== 'prod' && p !== 'dev').join('/');

  console.log('Parsed - Method:', httpMethod, 'Path:', path);

  // Handle CORS preflight
  if (httpMethod === 'OPTIONS') {
    return response(200, {});
  }

  try {
    // GET /files - List files (supports ?taskId=X for task-specific files)
    if (path.endsWith('/files') && httpMethod === 'GET') {
      const taskId = queryStringParameters?.taskId;
      const prefix = getPrefix(taskId);

      const command = new ListObjectsV2Command({
        Bucket: BUCKET_NAME,
        Prefix: prefix
      });
      const result = await s3Client.send(command);

      const files = (result.Contents || [])
        .filter(obj => obj.Key !== prefix)
        .map(obj => ({
          key: obj.Key,
          name: obj.Key.replace(prefix, ''),
          size: obj.Size,
          lastModified: obj.LastModified,
          taskId: taskId || null
        }));

      return response(200, { files, taskId: taskId || null });
    }

    // POST /upload - Get presigned URL for upload (supports taskId)
    if (path.endsWith('/upload') && httpMethod === 'POST') {
      const body = JSON.parse(event.body || '{}');
      const fileName = body.fileName || `file-${Date.now()}`;
      const contentType = body.contentType || 'application/octet-stream';
      const taskId = body.taskId;

      const prefix = getPrefix(taskId);
      const key = `${prefix}${fileName}`;

      const command = new PutObjectCommand({
        Bucket: BUCKET_NAME,
        Key: key,
        ContentType: contentType
      });

      const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn: 300 });

      return response(200, {
        uploadUrl,
        key,
        taskId: taskId || null,
        expiresIn: 300
      });
    }

    // GET /logs - Get recent Lambda logs
    if (path.endsWith('/logs') && httpMethod === 'GET') {
      const logGroupName = '/aws/lambda/s3-file-processor';

      // Get latest log stream
      const streamsCommand = new DescribeLogStreamsCommand({
        logGroupName,
        orderBy: 'LastEventTime',
        descending: true,
        limit: 1
      });

      const streamsResult = await logsClient.send(streamsCommand);

      if (!streamsResult.logStreams || streamsResult.logStreams.length === 0) {
        return response(200, { logs: [] });
      }

      const logStreamName = streamsResult.logStreams[0].logStreamName;

      // Get log events
      const eventsCommand = new GetLogEventsCommand({
        logGroupName,
        logStreamName,
        startFromHead: false,
        limit: 50
      });

      const eventsResult = await logsClient.send(eventsCommand);

      const logs = (eventsResult.events || []).map(event => ({
        timestamp: new Date(event.timestamp).toISOString(),
        message: event.message
      }));

      return response(200, { logs: logs.reverse() });
    }

    // DELETE /files - Delete a file (supports taskId)
    if (path.endsWith('/files') && httpMethod === 'DELETE') {
      const body = JSON.parse(event.body || '{}');
      const fileName = body.fileName;
      const taskId = body.taskId;

      if (!fileName) {
        return response(400, { error: 'fileName is required' });
      }

      const prefix = getPrefix(taskId);
      const key = `${prefix}${fileName}`;

      const command = new DeleteObjectCommand({
        Bucket: BUCKET_NAME,
        Key: key
      });

      await s3Client.send(command);

      return response(200, { message: 'File deleted', key, taskId: taskId || null });
    }

    return response(404, { error: 'Not found' });

  } catch (error) {
    console.error('Error:', error);
    return response(500, { error: error.message });
  }
};
