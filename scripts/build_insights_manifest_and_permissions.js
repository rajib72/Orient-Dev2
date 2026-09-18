const fs = require('fs');
const path = require('path');

const objectsDir = path.join(__dirname, '..', 'force-app', 'main', 'default', 'objects');
const insightObjects = [
    'Purchase_Behaviour_Insights__c',
    'Loyalty_Retention_Insights__c',
    'Product_Design_Preference_Insights__c',
    'Service_After_Sales_Insights__c',
    'Digital_Omni_Channel_Insights__c',
    'Financial_Scheme_Insights__c',
    'Visit_Store_Interaction_Insights__c',
    'Customer_Satisfaction_NPS_Insights__c',
    'Loyalty_Reward_Insights__c',
    'Risk_Compliance_Insights__c',
    'Referral_Advocacy_Insights__c',
    'Event_Occasion_Insights__c',
    'Engagement_Communication_Insights__c'
];

// Verify all directories exist
for (const obj of insightObjects) {
    const p = path.join(objectsDir, obj);
    if (!fs.existsSync(p)) {
        console.error('Missing object directory:', p);
    }
}

// Collect all fields
const objectFieldsMap = {};
let totalFieldCount = 0;

for (const obj of insightObjects) {
    const fieldsDir = path.join(objectsDir, obj, 'fields');
    if (!fs.existsSync(fieldsDir)) {
        objectFieldsMap[obj] = [];
        continue;
    }
    const files = fs.readdirSync(fieldsDir).filter(f => f.endsWith('.field-meta.xml'));
    objectFieldsMap[obj] = files.map(file => {
        const fieldName = file.replace('.field-meta.xml', '');
        const content = fs.readFileSync(path.join(fieldsDir, file), 'utf8');
        const isFormula = content.includes('<formula>') || content.includes('<formulaTreatBlanksAs>');
        const isAutoNumber = content.includes('<type>AutoNumber</type>');
        const isReadOnly = isFormula || isAutoNumber;
        return {
            fullName: `${obj}.${fieldName}`,
            object: obj,
            field: fieldName,
            isReadOnly
        };
    });
    totalFieldCount += objectFieldsMap[obj].length;
}

console.log(`Found ${insightObjects.length} objects and ${totalFieldCount} fields total.`);

// 1. Build package_insights.xml
let packageXml = `<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
`;

for (const obj of insightObjects) {
    packageXml += `        <members>${obj}</members>\n`;
}
packageXml += `        <name>CustomObject</name>
    </types>
    <types>
`;

for (const obj of insightObjects) {
    for (const f of objectFieldsMap[obj]) {
        packageXml += `        <members>${f.fullName}</members>\n`;
    }
}
packageXml += `        <name>CustomField</name>
    </types>
    <types>
        <members>Ctrl_PurchaseBehaviourInsights</members>
        <members>Ctrl_PurchaseBehaviourInsightsTest</members>
        <name>ApexClass</name>
    </types>
    <types>
        <members>customerPurchaseBehaviourInsights</members>
        <name>LightningComponentBundle</name>
    </types>
    <types>
        <members>*</members>
        <name>CustomTab</name>
    </types>
    <types>
        <members>*</members>
        <name>Layout</name>
    </types>
    <types>
        <members>Customer_Insights_Access</members>
        <name>PermissionSet</name>
    </types>
    <types>
        <members>Admin</members>
        <name>Profile</name>
    </types>
    <version>60.0</version>
</Package>
`;

fs.writeFileSync(path.join(__dirname, '..', 'manifest', 'package_insights.xml'), packageXml, 'utf8');
console.log('Created manifest/package_insights.xml');

// 2. Generate Permission Set Customer_Insights_Access
// This guarantees full visibility to all 292 fields and 13 objects without any profile mismatch issues!
const permSetDir = path.join(__dirname, '..', 'force-app', 'main', 'default', 'permissionsets');
if (!fs.existsSync(permSetDir)) {
    fs.mkdirSync(permSetDir, { recursive: true });
}

let permSetXml = `<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <description>Grants full read and edit access to all 13 Customer &amp; Purchase Behaviour Insights objects and fields.</description>
    <hasActivationRequired>false</hasActivationRequired>
    <label>Customer Insights Access</label>
`;

// Add Object Permissions
for (const obj of insightObjects) {
    permSetXml += `    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>true</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>true</modifyAllRecords>
        <object>${obj}</object>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>\n`;
}

// Add Field Permissions
for (const obj of insightObjects) {
    for (const f of objectFieldsMap[obj]) {
        // Customer_Name__c is Master-Detail? Let's check or lookup
        permSetXml += `    <fieldPermissions>
        <editable>${f.isReadOnly ? 'false' : 'true'}</editable>
        <field>${f.fullName}</field>
        <readable>true</readable>
    </fieldPermissions>\n`;
    }
}

permSetXml += `</PermissionSet>\n`;

fs.writeFileSync(path.join(permSetDir, 'Customer_Insights_Access.permissionset-meta.xml'), permSetXml, 'utf8');
console.log('Created permissionset: Customer_Insights_Access.permissionset-meta.xml');
