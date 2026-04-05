import XLSX from 'xlsx';
import puppeteer from 'puppeteer';

// GST Report Styles
const gstReportStyles = `
<style>
    @media print {
        body { margin: 0; padding: 20px; }
        .no-print { display: none; }
        .page-break { page-break-after: always; }
    }
    
    body { 
        font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; 
        padding: 20px; 
        line-height: 1.6; 
        color: #333; 
        max-width: 1200px; 
        margin: 0 auto; 
    }
    
    .header { 
        display: flex; 
        justify-content: space-between; 
        align-items: start;
        margin-bottom: 30px; 
        border-bottom: 3px solid #1BA672; 
        padding-bottom: 20px; 
    }
    
    .logo { 
        font-size: 28px; 
        font-weight: bold; 
        color: #1BA672; 
    }
    
    .vendor-info { 
        text-align: right; 
        font-size: 14px; 
    }
    
    .vendor-info h2 { 
        margin: 0 0 5px 0; 
        font-size: 20px; 
        color: #1A1A1A; 
    }
    
    .vendor-info .gstin { 
        font-weight: 600; 
        color: #1BA672; 
        font-size: 16px;
    }
    
    .report-title { 
        text-align: center; 
        margin: 20px 0 30px 0; 
    }
    
    .report-title h1 { 
        margin: 0 0 10px 0; 
        font-size: 24px; 
        color: #1A1A1A; 
    }
    
    .report-title .period { 
        font-size: 16px; 
        color: #6B6B6B; 
    }
    
    .summary-cards { 
        display: grid; 
        grid-template-columns: repeat(4, 1fr); 
        gap: 20px; 
        margin-bottom: 30px; 
    }
    
    .summary-card { 
        background: linear-gradient(135deg, #1BA672 0%, #14885E 100%); 
        color: white; 
        padding: 20px; 
        border-radius: 12px; 
        box-shadow: 0 4px 10px rgba(27, 166, 114, 0.25); 
    }
    
    .summary-card.secondary { 
        background: linear-gradient(135deg, #E85A1C 0%, #CC4E17 100%); 
    }
    
    .summary-card h3 { 
        margin: 0 0 8px 0; 
        font-size: 14px; 
        font-weight: 500; 
        opacity: 0.9; 
    }
    
    .summary-card .value { 
        font-size: 28px; 
        font-weight: 700; 
        margin: 0; 
    }
    
    .section { 
        margin-bottom: 40px; 
    }
    
    .section h2 { 
        font-size: 20px; 
        color: #1A1A1A; 
        margin-bottom: 15px; 
        border-bottom: 2px solid #E0E0E0; 
        padding-bottom: 10px; 
    }
    
    table { 
        width: 100%; 
        border-collapse: collapse; 
        margin-bottom: 20px; 
        background: white; 
    }
    
    th { 
        text-align: left; 
        padding: 12px; 
        background: #F9F9F9; 
        font-weight: 600; 
        border-bottom: 2px solid #E0E0E0; 
        font-size: 13px; 
        text-transform: uppercase; 
        color: #6B6B6B; 
    }
    
    td { 
        padding: 12px; 
        border-bottom: 1px solid #F0F0F0; 
        font-size: 14px; 
    }
    
    tr:hover { 
        background: #FAFAFA; 
    }
    
    .text-right { 
        text-align: right; 
    }
    
    .text-center { 
        text-align: center; 
    }
    
    .total-row td { 
        font-weight: 700; 
        background: #F0FCF7; 
        border-top: 2px solid #1BA672; 
        font-size: 15px; 
    }
    
    .gst-filing-guide { 
        background: #E8F6F1; 
        border-left: 4px solid #1BA672; 
        padding: 20px; 
        margin-top: 30px; 
        border-radius: 8px; 
    }
    
    .gst-filing-guide h3 { 
        margin: 0 0 15px 0; 
        color: #1BA672; 
        font-size: 18px; 
    }
    
    .gst-filing-guide .filing-item { 
        margin-bottom: 15px; 
        padding-bottom: 15px; 
        border-bottom: 1px solid #CDEBDD; 
    }
    
    .gst-filing-guide .filing-item:last-child { 
        border-bottom: none; 
    }
    
    .gst-filing-guide strong { 
        color: #0E6B49; 
    }
    
    .footer { 
        text-align: center; 
        font-size: 12px; 
        color: #999; 
        margin-top: 50px; 
        padding-top: 20px; 
        border-top: 1px solid #E0E0E0; 
    }
</style>
`;

/**
 * Generate HTML GST Report
 */
function generateGSTReportHTML(data) {
    const { vendor, period, orders, summary, gst_filing_summary } = data;

    const stateBreakupHTML = Object.entries(summary.state_wise_breakup || {})
        .map(([state, stats]) => `
            <tr>
                <td>${state}</td>
                <td class="text-right">${stats.orders}</td>
                <td class="text-right">₹${Number(stats.value).toFixed(2)}</td>
                <td class="text-right">₹${Number(stats.gst).toFixed(2)}</td>
            </tr>
        `).join('');

    const ordersHTML = orders.map(order => `
        <tr>
            <td>${new Date(order.date).toLocaleDateString('en-IN')}</td>
            <td>${order.order_number}</td>
            <td>${order.customer_state || 'N/A'}</td>
            <td class="text-right">₹${Number(order.item_total).toFixed(2)}</td>
            <td class="text-right">₹${Number(order.gst_on_items).toFixed(2)}</td>
            <td class="text-right">₹${Number(order.platform_fee || 0).toFixed(2)}</td>
            <td class="text-right">₹${Number(order.gst_on_fees).toFixed(2)}</td>
            <td class="text-right">₹${Number(order.gross_amount).toFixed(2)}</td>
            <td class="text-right">₹${Number(order.commission || 0).toFixed(2)}</td>
            <td class="text-right">₹${Number(order.tds_tcs || 0).toFixed(2)}</td>
            <td class="text-right"><strong>₹${Number(order.net_settlement).toFixed(2)}</strong></td>
        </tr>
    `).join('');

    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GST Report - ${vendor.name} - ${period.month}</title>
    ${gstReportStyles}
</head>
<body>
    <div class="header">
        <div>
            <div class="logo">GUTZO</div>
            <div style="font-size: 14px; color: #6B6B6B; margin-top: 5px;">E-Commerce Operator</div>
        </div>
        <div class="vendor-info">
            <h2>${vendor.name}</h2>
            <div>${vendor.address || ''}</div>
            <div class="gstin">GSTIN: ${vendor.gstin || 'N/A'}</div>
        </div>
    </div>

    <div class="report-title">
        <h1>GST Report</h1>
        <div class="period">Period: ${new Date(period.from).toLocaleDateString('en-IN')} to ${new Date(period.to).toLocaleDateString('en-IN')}</div>
        <div class="period" style="font-weight: 600; color: #1BA672; margin-top: 5px;">${period.month}</div>
    </div>

    <div class="summary-cards">
        <div class="summary-card">
            <h3>Total Orders</h3>
            <div class="value">${summary.total_orders}</div>
        </div>
        <div class="summary-card">
            <h3>Total Sales Value</h3>
            <div class="value">₹${Number(summary.total_sales_value).toFixed(2)}</div>
        </div>
        <div class="summary-card">
            <h3>Total GST @ 5%</h3>
            <div class="value">₹${Number(summary.total_gst_collected_5_percent).toFixed(2)}</div>
        </div>
        <div class="summary-card secondary">
            <h3>Net Settlement</h3>
            <div class="value">₹${Number(summary.net_settlement_amount).toFixed(2)}</div>
        </div>
    </div>

    <div class="section">
        <h2>State-wise Sales Breakup</h2>
        <table>
            <thead>
                <tr>
                    <th>State</th>
                    <th class="text-right">Orders</th>
                    <th class="text-right">Sales Value</th>
                    <th class="text-right">GST @ 5%</th>
                </tr>
            </thead>
            <tbody>
                ${stateBreakupHTML}
                <tr class="total-row">
                    <td>TOTAL</td>
                    <td class="text-right">${summary.total_orders}</td>
                    <td class="text-right">₹${Number(summary.total_sales_value).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.total_gst_collected_5_percent).toFixed(2)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    <div class="section page-break">
        <h2>Order Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Order #</th>
                    <th>State</th>
                    <th class="text-right">Items</th>
                    <th class="text-right">GST@5%</th>
                    <th class="text-right">Platform Fee</th>
                    <th class="text-right">GST@18%</th>
                    <th class="text-right">Gross</th>
                    <th class="text-right">Commission</th>
                    <th class="text-right">TDS/TCS</th>
                    <th class="text-right">Net Settlement</th>
                </tr>
            </thead>
            <tbody>
                ${ordersHTML}
                <tr class="total-row">
                    <td colspan="3">TOTAL</td>
                    <td class="text-right">₹${Number(summary.total_sales_value).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.total_gst_collected_5_percent).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.total_platform_fees).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.total_gst_on_fees_18_percent).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.gross_revenue).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.total_commission || 0).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.total_tds_tcs || 0).toFixed(2)}</td>
                    <td class="text-right">₹${Number(summary.net_settlement_amount).toFixed(2)}</td>
                </tr>
            </tbody>
        </table>
    </div>

    ${gst_filing_summary ? `
    <div class="gst-filing-guide">
        <h3>📋 GST Filing Guide</h3>
        
        <div class="filing-item">
            <strong>GSTR-1 - Table 8:</strong> Supplies through E-Commerce Operator (ECO)
            <div style="margin-top: 5px;">
                Taxable Value: ₹${Number(gst_filing_summary.table_8_gstr1.taxable_value).toFixed(2)}<br>
                Tax Paid by ECO (Gutzo): ₹${Number(gst_filing_summary.table_8_gstr1.tax_paid_by_eco).toFixed(2)}
            </div>
        </div>
        
        <div class="filing-item">
            <strong>GSTR-3B - Table 3.1.1(ii):</strong> Supplies through ECO
            <div style="margin-top: 5px;">
                Taxable Value: ₹${Number(gst_filing_summary.table_3_1_1_ii_gstr3b.taxable_value).toFixed(2)}<br>
                <em style="color: #0E6B49;">Note: ${gst_filing_summary.table_3_1_1_ii_gstr3b.note}</em>
            </div>
        </div>
    </div>
    ` : ''}

    <div class="footer">
        <p>This is a computer-generated GST report from Gutzo for vendor filing purposes.</p>
        <p>Generated on: ${new Date().toLocaleDateString('en-IN')} at ${new Date().toLocaleTimeString('en-IN')}</p>
    </div>
</body>
</html>
    `;
}

/**
 * Generate PDF from HTML
 */
async function generateGSTReportPDF(data) {
    console.log('Starting PDF generation...');
    const html = generateGSTReportHTML(data);
    console.log('HTML generated, length:', html.length);

    let browser;
    try {
        console.log('Launching Puppeteer browser...');
        browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--disable-gpu'
            ],
            timeout: 30000 // 30 second timeout
        });
        console.log('Browser launched successfully');

        const page = await browser.newPage();
        console.log('New page created');

        await page.setContent(html, {
            waitUntil: 'networkidle0',
            timeout: 30000
        });
        console.log('HTML content set');

        const pdf = await page.pdf({
            format: 'A4',
            landscape: true,
            printBackground: true,
            margin: {
                top: '20px',
                right: '20px',
                bottom: '20px',
                left: '20px'
            }
        });
        console.log('PDF generated, size:', pdf.length, 'bytes');

        return pdf;
    } catch (error) {
        console.error('PDF generation error:', error);
        throw new Error(`Failed to generate PDF: ${error.message}`);
    } finally {
        if (browser) {
            await browser.close();
            console.log('Browser closed');
        }
    }
}

/**
 * Generate Excel workbook
 */
function generateGSTReportExcel(data) {
    const { vendor, period, orders, summary, gst_filing_summary } = data;

    const workbook = XLSX.utils.book_new();

    // Sheet 1: Summary
    const summaryData = [
        ['GST REPORT'],
        ['Vendor', vendor.name],
        ['GSTIN', vendor.gstin || 'N/A'],
        ['Period', `${new Date(period.from).toLocaleDateString('en-IN')} to ${new Date(period.to).toLocaleDateString('en-IN')}`],
        [],
        ['Summary'],
        ['Total Orders', summary.total_orders],
        ['Total Sales Value', Number(summary.total_sales_value).toFixed(2)],
        ['Total GST @ 5%', Number(summary.total_gst_collected_5_percent).toFixed(2)],
        ['Total Platform Fees', Number(summary.total_platform_fees).toFixed(2)],
        ['Total GST @ 18%', Number(summary.total_gst_on_fees_18_percent).toFixed(2)],
        ['Gross Revenue', Number(summary.gross_revenue).toFixed(2)],
        ['Total Commission', Number(summary.total_commission || 0).toFixed(2)],
        ['Total TDS/TCS', Number(summary.total_tds_tcs || 0).toFixed(2)],
        ['Net Settlement Amount', Number(summary.net_settlement_amount).toFixed(2)]
    ];
    const summarySheet = XLSX.utils.aoa_to_sheet(summaryData);
    XLSX.utils.book_append_sheet(workbook, summarySheet, 'Summary');

    // Sheet 2: State-wise Breakup
    const stateData = [
        ['State', 'Orders', 'Sales Value', 'GST @ 5%'],
        ...Object.entries(summary.state_wise_breakup || {}).map(([state, stats]) => [
            state,
            stats.orders,
            Number(stats.value).toFixed(2),
            Number(stats.gst).toFixed(2)
        ]),
        ['TOTAL', summary.total_orders, Number(summary.total_sales_value).toFixed(2), Number(summary.total_gst_collected_5_percent).toFixed(2)]
    ];
    const stateSheet = XLSX.utils.aoa_to_sheet(stateData);
    XLSX.utils.book_append_sheet(workbook, stateSheet, 'State-wise Breakup');

    // Sheet 3: Order Details
    const orderData = [
        ['Date', 'Order #', 'State', 'Items', 'GST@5%', 'Platform Fee', 'GST@18%', 'Gross', 'Commission', 'TDS/TCS', 'Net Settlement'],
        ...orders.map(order => [
            new Date(order.date).toLocaleDateString('en-IN'),
            order.order_number,
            order.customer_state || 'N/A',
            Number(order.item_total).toFixed(2),
            Number(order.gst_on_items).toFixed(2),
            Number(order.platform_fee || 0).toFixed(2),
            Number(order.gst_on_fees).toFixed(2),
            Number(order.gross_amount).toFixed(2),
            Number(order.commission || 0).toFixed(2),
            Number(order.tds_tcs || 0).toFixed(2),
            Number(order.net_settlement).toFixed(2)
        ]),
        [
            'TOTAL', '', '',
            Number(summary.total_sales_value).toFixed(2),
            Number(summary.total_gst_collected_5_percent).toFixed(2),
            Number(summary.total_platform_fees).toFixed(2),
            Number(summary.total_gst_on_fees_18_percent).toFixed(2),
            Number(summary.gross_revenue).toFixed(2),
            Number(summary.total_commission || 0).toFixed(2),
            Number(summary.total_tds_tcs || 0).toFixed(2),
            Number(summary.net_settlement_amount).toFixed(2)
        ]
    ];
    const orderSheet = XLSX.utils.aoa_to_sheet(orderData);
    XLSX.utils.book_append_sheet(workbook, orderSheet, 'Order Details');

    // Sheet 4: GST Filing Guide
    if (gst_filing_summary) {
        const filingData = [
            ['GST FILING GUIDE'],
            [],
            ['GSTR-1 - Table 8'],
            ['Description', gst_filing_summary.table_8_gstr1.description],
            ['Taxable Value', Number(gst_filing_summary.table_8_gstr1.taxable_value).toFixed(2)],
            ['Tax Paid by ECO', Number(gst_filing_summary.table_8_gstr1.tax_paid_by_eco).toFixed(2)],
            [],
            ['GSTR-3B - Table 3.1.1(ii)'],
            ['Description', gst_filing_summary.table_3_1_1_ii_gstr3b.description],
            ['Taxable Value', Number(gst_filing_summary.table_3_1_1_ii_gstr3b.taxable_value).toFixed(2)],
            ['Note', gst_filing_summary.table_3_1_1_ii_gstr3b.note]
        ];
        const filingSheet = XLSX.utils.aoa_to_sheet(filingData);
        XLSX.utils.book_append_sheet(workbook, filingSheet, 'GST Filing Guide');
    }

    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
}

export {
    generateGSTReportHTML,
    generateGSTReportPDF,
    generateGSTReportExcel
};
