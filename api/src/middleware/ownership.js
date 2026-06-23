const { db } = require('../db/index');
const { tenants, bills, comments, chats } = require('../db/schema');
const { eq } = require('drizzle-orm');

function verifyOwnership(resourceType) {
  return async (req, res, next) => {
    const userId = req.user.id;
    const role = req.user.role;
    const resourceId = req.params.id;

    // Landlord / Owner bypasses ownership restrictions for business ops
    if (role === 'owner') {
      return next();
    }

    try {
      if (resourceType === 'tenant') {
        // Tenants can only access their own profile details
        // In this case, either resourceId matches the tenant's ID, or we verify by user_id link
        const tenantRecords = await db.select().from(tenants).where(eq(tenants.id, resourceId));
        if (tenantRecords.length === 0) {
          return res.status(404).json({ message: 'Tenant record not found.' });
        }
        
        const tenant = tenantRecords[0];
        if (tenant.userId !== userId && tenant.id !== userId) {
          return res.status(403).json({ message: 'Forbidden. You do not own this profile.' });
        }
      } 
      
      else if (resourceType === 'bill') {
        // Tenants can only view their own bill items
        const billRecords = await db.select().from(bills).where(eq(bills.id, resourceId));
        if (billRecords.length === 0) {
          return res.status(404).json({ message: 'Bill invoice not found.' });
        }
        
        const bill = billRecords[0];
        // We find the tenant linked to this user
        const tenantRecords = await db.select().from(tenants).where(eq(tenants.userId, userId));
        if (tenantRecords.length === 0 || bill.tenantId !== tenantRecords[0].id) {
          return res.status(403).json({ message: 'Forbidden. You are not authorized to view this bill.' });
        }
      } 
      
      else if (resourceType === 'comment') {
        // Tenants can only view/reply to comments that they created
        const commentRecords = await db.select().from(comments).where(eq(comments.id, resourceId));
        if (commentRecords.length === 0) {
          return res.status(404).json({ message: 'Ticket thread not found.' });
        }
        
        const comment = commentRecords[0];
        const tenantRecords = await db.select().from(tenants).where(eq(tenants.userId, userId));
        if (tenantRecords.length === 0 || comment.tenantId !== tenantRecords[0].id) {
          return res.status(403).json({ message: 'Forbidden. Access to this ticket thread is restricted.' });
        }
      } 
      
      else if (resourceType === 'chat') {
        // Tenants can only view/send chats on their own inbox thread
        // In direct chat endpoints, the path parameter is usually the tenantId
        const tenantRecords = await db.select().from(tenants).where(eq(tenants.userId, userId));
        if (tenantRecords.length === 0 || resourceId !== tenantRecords[0].id) {
          return res.status(403).json({ message: 'Forbidden. Access to this chat channel is restricted.' });
        }
      }

      next();
    } catch (error) {
      console.error('Ownership validation error:', error.message);
      return res.status(500).json({ message: 'Something went wrong.' });
    }
  };
}

module.exports = {
  verifyOwnership
};
