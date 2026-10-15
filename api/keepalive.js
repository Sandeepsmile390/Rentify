export default async function handler(req, res) {
  try {
    const supabaseUrl = process.env.SUPABASE_URL || 'https://hxzuxainrstkobczijdu.supabase.co';
    const supabaseKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh4enV4YWlucnN0a29iY3ppamR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM1NzgwNTgsImV4cCI6MjA1OTE1NDA1OH0.3z7t71z6nC-kHsmC3G27ZqGj3y8aQ9R3b7V0x6F5e2o';

    const response = await fetch(`${supabaseUrl}/rest/v1/health_pings`, {
      method: 'POST',
      headers: {
        'apikey': supabaseKey,
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify({ ping_source: 'vercel_cron' })
    });

    return res.status(200).json({
      status: 'ok',
      message: 'Supabase heartbeat pinged successfully',
      timestamp: new Date().toISOString(),
      supabaseStatus: response.status
    });
  } catch (error) {
    return res.status(500).json({
      status: 'error',
      message: error.message
    });
  }
}
