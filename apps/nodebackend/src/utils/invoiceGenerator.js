import fs from 'fs';
import path from 'path';
import puppeteer from 'puppeteer';

// CSS for Invoice (Common)
const invoiceStyles = `
<style>
    body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; padding: 20px; line-height: 1.4; color: #333; max-width: 800px; margin: 0 auto; }
    .header { display: flex; justify-content: space-between; margin-bottom: 20px; border-bottom: 2px solid #eee; padding-bottom: 20px; }
    .logo { font-size: 24px; font-weight: bold; color: #1BA672; }
    .meta { text-align: right; font-size: 14px; color: #666; }
    h2 { margin: 0 0 10px 0; font-size: 18px; }
    .section { margin-bottom: 30px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    th { text-align: left; padding: 10px; background: #f9f9f9; font-weight: 600; border-bottom: 1px solid #ddd; font-size: 12px; text-transform: uppercase; color: #555; }
    td { padding: 10px; border-bottom: 1px solid #eee; font-size: 14px; }
    .text-right { text-align: right; }
    .total-row td { font-weight: bold; border-top: 2px solid #ddd; background: #fdfdfd; }
    .footer { text-align: center; font-size: 12px; color: #999; margin-top: 40px; border-top: 1px solid #eee; padding-top: 20px; }
    .badge { padding: 4px 8px; border-radius: 4px; font-size: 10px; font-weight: bold; text-transform: uppercase; }
    .badge-paid { background: #dcfce7; color: #15803d; }
    .badge-pending { background: #fef9c3; color: #a16207; }
    .small { font-size: 12px; color: #666; }
</style>
`;

/**
 * Generate Customer Tax Invoice HTML
 */
export const generateCustomerInvoiceHtml = (order) => {
    const date = new Date(order.created_at).toLocaleString('en-IN', { dateStyle: 'long', timeStyle: 'short' });
    const paymentStatus = order.payment_status === 'paid' ? 'PAID' : 'PENDING';
    const paymentMethod = order.payment_method?.toUpperCase() || 'N/A';

    // Vendor Info
    const vendorName = order.vendor?.name || 'Restaurant Partner';
    const vendorAddress = order.vendor?.address || '';

    let vendorTaxLabel = 'GSTIN:';
    let vendorTaxValue = 'N/A';

    // Clean inputs (handle actual null, undefined, padding spaces, and literal "null"/"N/A" strings)
    const gstNo = order.vendor?.gst_number?.trim();
    const panNo = order.vendor?.pan_card_no?.trim();

    if (gstNo && gstNo.toUpperCase() !== 'N/A' && gstNo.toLowerCase() !== 'null') {
        vendorTaxValue = gstNo;
    } else if (panNo && panNo.toUpperCase() !== 'N/A' && panNo.toLowerCase() !== 'null') {
        vendorTaxLabel = 'PAN:';
        vendorTaxValue = panNo;
    }

    // Parse delivery address if it's a JSON string
    let deliveryAddress = order.delivery_address;
    if (typeof deliveryAddress === 'string') {
        try {
            deliveryAddress = JSON.parse(deliveryAddress);
        } catch (e) {
            // If parsing fails, treat entire string as address
            deliveryAddress = { address: deliveryAddress };
        }
    }

    // Ensure deliveryAddress is an object with fallback values
    if (!deliveryAddress || typeof deliveryAddress !== 'object') {
        deliveryAddress = {};
    }

    const customerName = order.user?.name || deliveryAddress.name || 'Customer';
    const customerAddress = deliveryAddress.address || deliveryAddress.full_address || 'Address not provided';

    // Calculation Breakdown
    const subtotal = Number(order.subtotal || 0).toFixed(2);
    const packaging = Number(order.packaging_fee || 0).toFixed(2);

    // Calculate restaurant GST (5%) if not already stored
    const itemBase = Number(order.subtotal || 0) + Number(order.packaging_fee || 0);
    const itemTax = Number(order.gst_items || (itemBase * 5 / 105)).toFixed(2);

    const deliveryFee = Number(order.delivery_fee || 0).toFixed(2);
    const platformFee = Number(order.platform_fee || 0).toFixed(2);

    // Calculate platform GST (18%) if not already stored
    const feeBase = Number(order.delivery_fee || 0) + Number(order.platform_fee || 0);
    const feeTax = Number(order.gst_fees || (feeBase * 18 / 118)).toFixed(2);

    const total = Number(order.total_amount || 0).toFixed(2);
    const discount = Number(order.discount_amount || 0).toFixed(2);

    let itemsHtml = '';
    if (order.items && order.items.length > 0) {
        itemsHtml = order.items.map(item => `
            <tr>
                <td>
                    <div style="font-weight:500">${item.product_name}</div>
                    ${item.customizations ? `<div class="small">${item.customizations}</div>` : ''}
                </td>
                <td class="text-right">${item.quantity}</td>
                <td class="text-right">₹${Number(item.unit_price).toFixed(2)}</td>
                <td class="text-right">₹${Number(item.total_price).toFixed(2)}</td>
            </tr>
        `).join('');
    }

    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Invoice #${order.order_number}</title>
    ${invoiceStyles}
</head>
<body>
    <div class="header">
        <div>
            <div class="logo">GUTZO</div>
            <div class="small">Tax Invoice</div>
            <div class="small" style="margin-top:2px;">GSTIN: ${process.env.GUTZO_GSTIN || '33CFFPM6751J1Z8'}</div>
        </div>
        <div class="meta">
            <div><strong>Order #${order.order_number}</strong></div>
            <div>Date: ${date}</div>
            <div style="margin-top:5px">
                <span class="badge badge-${order.payment_status === 'paid' ? 'paid' : 'pending'}">${paymentStatus}</span>
            </div>
        </div>
    </div>

    <div class="section">
        <div style="display:flex; gap: 40px;">
            <div style="flex:1">
                <div class="small" style="text-transform:uppercase; margin-bottom:5px; font-weight:bold;">Ordered From</div>
                <h2>${vendorName}</h2>
                <div class="small">${vendorAddress}</div>
                <div class="small">${vendorTaxLabel} ${vendorTaxValue}</div>
            </div>
            <div style="flex:1">
                <div class="small" style="text-transform:uppercase; margin-bottom:5px; font-weight:bold;">Delivered To</div>
                <div style="font-weight:600">${customerName}</div>
                <div class="small">${customerAddress}</div>
                <div class="small">Phone: ${order.delivery_phone}</div>
            </div>
        </div>
    </div>

    <div class="section">
        <h3>Order Summary</h3>
        <table>
            <thead>
                <tr>
                    <th>Item</th>
                    <th class="text-right" width="60">Qty</th>
                    <th class="text-right" width="100">Price</th>
                    <th class="text-right" width="100">Total</th>
                </tr>
            </thead>
            <tbody>
                ${itemsHtml}
            </tbody>
        </table>
    </div>

    <div class="section">
        <div style="display:flex; justify-content:flex-end">
            <div style="width:300px">
                <table style="margin:0">
                    <tr>
                        <td>Item Total</td>
                        <td class="text-right">₹${subtotal}</td>
                    </tr>
                    ${Number(packaging) > 0 ? `
                    <tr>
                        <td>Packaging Charges</td>
                        <td class="text-right">₹${packaging}</td>
                    </tr>` : ''}
                    <tr>
                        <td style="color:#555">Restaurant GST (5%)</td>
                        <td class="text-right" style="color:#555; font-size:12px;">(Inc. ₹${itemTax})</td>
                    </tr>
                    
                    <tr><td colspan="2" style="border-bottom:1px dashed #ddd"></td></tr>

                    <tr>
                        <td>Delivery Partner Fee</td>
                        <td class="text-right">₹${deliveryFee}</td>
                    </tr>
                    <tr>
                        <td>Platform Fee</td>
                        <td class="text-right">₹${platformFee}</td>
                    </tr>
                     <tr>
                        <td style="color:#555">Taxes on Fees (18%)</td>
                        <td class="text-right" style="color:#555; font-size:12px;">(Inc. ₹${feeTax})</td>
                    </tr>
                    
                    ${Number(discount) > 0 ? `
                    <tr>
                        <td style="color:#1BA672">Discount</td>
                        <td class="text-right" style="color:#1BA672">- ₹${discount}</td>
                    </tr>` : ''}

                    <tr class="total-row">
                        <td style="font-size:16px">Grand Total</td>
                        <td class="text-right" style="font-size:16px">₹${total}</td>
                    </tr>
                    <tr>
                         <td class="small">Payment Mode</td>
                         <td class="text-right small">${paymentMethod}</td>
                    </tr>
                </table>
            </div>
        </div>
    </div>

    <div class="footer">
        <p>Thank you for ordering from Gutzo!</p>
        <p class="small" style="margin-top:5px">This is a computer generated invoice.</p>
    </div>
</body>
</html>
    `;
};


/**
 * Generate Vendor Summary (Kitchen Print / Vendor Copy)
 */
export const generateVendorKOTHtml = (order) => {
    const date = new Date(order.created_at).toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' });

    let itemsHtml = (order.items || []).map(item => `
        <div style="border-bottom:1px dashed #ccc; padding: 10px 0;">
            <div style="display:flex; justify-content:space-between; font-weight:bold; font-size:16px;">
                <span>${item.quantity} x ${item.product_name}</span>
                <span></span>
            </div>
             ${item.customizations ? `<div style="font-size:14px; color:#555; margin-top:4px;">Note: ${item.customizations}</div>` : ''}
        </div>
    `).join('');

    return `
<!DOCTYPE html>
<html>
<head>
    <title>KOT #${order.order_number}</title>
    <style>
        body { font-family: 'Courier New', Courier, monospace; padding: 20px; max-width: 400px; margin: 0 auto; background: #fff; }
        .header { text-align: center; border-bottom: 2px solid #000; padding-bottom: 15px; margin-bottom: 15px; }
        h1 { margin: 0; font-size: 24px; }
        .meta { font-size: 14px; margin-top: 5px; }
        .items { margin-bottom: 20px; }
        .footer { text-align: center; font-size: 12px; margin-top: 20px; border-top: 1px solid #000; padding-top: 10px; }
        .tag { display:inline-block; background:#000; color:#fff; padding:2px 6px; font-weight:bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>KITCHEN TICKET</h1>
        <div class="meta" style="font-size:18px; font-weight:bold; margin:10px 0;">#${order.order_number}</div>
        <div class="meta">Date: ${date}</div>
        <div class="meta">Type: <span class="tag">${order.order_type || 'DELIVERY'}</span></div>
    </div>

    <div class="items">
        ${itemsHtml}
    </div>

    <div style="margin-top:20px; border-top: 2px solid #000; padding-top:10px;">
         <div style="font-weight:bold">Special Instructions:</div>
         <div style="font-size:14px; margin-top:5px;">${order.special_instructions || 'None'}</div>
    </div>

    <div class="footer">
        Gutzo Partner App
    </div>
    
    <script>
        // Auto-print prompt
        // window.print();
    </script>
</body>
</html>
    `;
};

/**
 * Generate PDF from Invoice HTML
 */
export const generateInvoicePDF = async (order) => {
    const html = generateCustomerInvoiceHtml(order);

    let browser;
    try {
        browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--disable-gpu'
            ],
            timeout: 30000
        });

        const page = await browser.newPage();
        await page.setContent(html, {
            waitUntil: 'networkidle0',
            timeout: 30000
        });

        const pdf = await page.pdf({
            format: 'A4',
            printBackground: true,
            margin: {
                top: '20px',
                right: '20px',
                bottom: '20px',
                left: '20px'
            }
        });

        return pdf;
    } catch (error) {
        throw new Error(`Failed to generate PDF: ${error.message}`);
    } finally {
        if (browser) {
            await browser.close();
        }
    }
};
