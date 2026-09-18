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

const customerId = '001C400000XfqnBIAR';
let apexLines = [];
apexLines.push(`Id custId = '${customerId}';\n`);

apexLines.push(`// Clean up any existing records for this customer to ensure exactly one record per object`);
insightObjects.forEach(obj => {
    apexLines.push(`delete [SELECT Id FROM ${obj} WHERE Customer_Name__c = :custId];`);
});
apexLines.push('\n');

insightObjects.forEach((obj, idx) => {
    const varName = 'rec' + (idx + 1);
    apexLines.push(`// ================= ${obj} =================`);
    apexLines.push(`${obj} ${varName} = new ${obj}();`);
    apexLines.push(`${varName}.Customer_Name__c = custId;`);
    
    const fDir = path.join(objectsDir, obj, 'fields');
    const files = fs.readdirSync(fDir).filter(f => f.endsWith('.field-meta.xml'));
    
    files.forEach(f => {
        const fname = f.replace('.field-meta.xml', '');
        if (fname === 'Customer_Name__c') return;
        
        const content = fs.readFileSync(path.join(fDir, f), 'utf8');
        if (content.includes('<formula>') || content.includes('<formulaTreatBlanksAs>') || content.includes('<type>AutoNumber</type>')) {
            return; // skip formulas & auto numbers
        }
        
        const typeMatch = content.match(/<type>([^<]+)<\/type>/);
        const type = typeMatch ? typeMatch[1] : 'Text';
        const labelMatch = content.match(/<label>([^<]+)<\/label>/);
        const label = labelMatch ? labelMatch[1] : fname;
        
        let valStr = null;
        if (type === 'Checkbox') {
            valStr = 'true';
        } else if (type === 'Currency' || type === 'Number' || type === 'Percent') {
            const precisionMatch = content.match(/<precision>([0-9]+)<\/precision>/);
            const scaleMatch = content.match(/<scale>([0-9]+)<\/scale>/);
            const scale = scaleMatch ? parseInt(scaleMatch[1], 10) : 0;
            if (fname.toLowerCase().includes('score') || fname.toLowerCase().includes('rating')) {
                valStr = '8';
            } else if (fname.toLowerCase().includes('rate') || fname.toLowerCase().includes('percent') || type === 'Percent') {
                valStr = '85';
            } else if (fname.toLowerCase().includes('count') || fname.toLowerCase().includes('frequency') || fname.toLowerCase().includes('days') || fname.toLowerCase().includes('visits') || fname.toLowerCase().includes('gap') || fname.toLowerCase().includes('time')) {
                valStr = '12';
            } else if (fname.toLowerCase().includes('weight')) {
                valStr = '18.5';
            } else if (fname.toLowerCase().includes('size') || fname.toLowerCase().includes('value') || fname.toLowerCase().includes('amount') || fname.toLowerCase().includes('cost') || fname.toLowerCase().includes('balance') || type === 'Currency') {
                valStr = '75000';
            } else {
                valStr = '10';
            }
        } else if (type === 'Date') {
            if (fname.toLowerCase().includes('next') || fname.toLowerCase().includes('expiry') || fname.toLowerCase().includes('expected')) {
                valStr = 'Date.today().addDays(30)';
            } else {
                valStr = 'Date.today().addDays(-15)';
            }
        } else if (type === 'DateTime') {
            valStr = 'Datetime.now().addDays(-5)';
        } else if (type === 'Picklist' || type === 'MultiselectPicklist') {
            const vals = [...content.matchAll(/<fullName>([^<]+)<\/fullName>/g)].map(m => m[1]);
            if (vals.length > 0) {
                valStr = `'` + vals[0].replace(/'/g, "\\'") + `'`;
            } else {
                valStr = `'Active'`;
            }
        } else if (type === 'Phone') {
            valStr = `'6289792391'`;
        } else if (type === 'Email') {
            valStr = `'rajibsarkar7257@gmail.com'`;
        } else if (type === 'Url') {
            valStr = `'https://orientjewellers.com'`;
        } else {
            // Text or TextArea
            const lengthMatch = content.match(/<length>([0-9]+)<\/length>/);
            const len = lengthMatch ? parseInt(lengthMatch[1], 10) : 255;
            let sampleText = label + ' - Sample';
            if (sampleText.length > len) {
                sampleText = sampleText.substring(0, len);
            }
            valStr = `'` + sampleText.replace(/'/g, "\\'") + `'`;
        }
        
        if (valStr !== null) {
            apexLines.push(`${varName}.${fname} = ${valStr};`);
        }
    });
    
    apexLines.push(`insert ${varName};\n`);
});

apexLines.push(`System.debug('SUCCESS: Created all 13 sample insight records for customer ' + custId);`);
const outPath = path.join(__dirname, 'create_sample_data.apex');
fs.writeFileSync(outPath, apexLines.join('\n'), 'utf8');
console.log('Generated', outPath);
