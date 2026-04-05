// Native fetch is available in Node.js 18+

const BASE_URL = 'http://127.0.0.1:5000/api';
const TEST_PHONE = '+919003802398'; // Found from verify_db.js

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  bold: '\x1b[1m'
};

const report = {
  passed: 0,
  failed: 0,
  results: []
};

async function testEndpoint(name, url, method = 'GET', headers = {}, expectedStatus = 200) {
  try {
    const start = Date.now();
    const res = await fetch(`${BASE_URL}${url}`, { method, headers });
    const duration = Date.now() - start;
    
    let data;
    const contentType = res.headers.get('content-type');
    if (contentType && contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }

    const passed = res.status === expectedStatus;
    
    if (passed) report.passed++;
    else report.failed++;

    report.results.push({
      name,
      url,
      method,
      status: res.status,
      expected: expectedStatus,
      duration,
      passed,
      error: !passed ? (data.message || data.error || JSON.stringify(data)) : null
    });

    const statusColor = passed ? colors.green : colors.red;
    console.log(`${statusColor}[${res.status}] ${method} ${url} - ${name}${colors.reset} (${duration}ms)`);
    if (!passed) {
        console.log(`    ${colors.yellow}Expected: ${expectedStatus}, Got: ${res.status}${colors.reset}`);
        console.log(`    Error: ${JSON.stringify(data)}`);
    }

  } catch (err) {
    report.failed++;
    report.results.push({
      name,
      url,
      method,
      status: 'ERR',
      expected: expectedStatus,
      passed: false,
      error: err.message
    });
    console.log(`${colors.red}[ERR] ${method} ${url} - ${name}${colors.reset}`);
    console.log(`    Error: ${err.message}`);
  }
}

async function runTests() {
  console.log(`${colors.bold}\n🚀 Starting Gutzo API Health Check...${colors.reset}\n`);

  // 1. Health Check
  await testEndpoint('Health Check', '/health');

  // 2. Public Endpoints
  await testEndpoint('Get All Vendors', '/vendors');
  await testEndpoint('Get Vendors (Filtered)', '/vendors?cuisine=Indian');
  await testEndpoint('Get All Products', '/products?limit=5');
  
  // 3. Vendor Specific (Need a valid ID from vendor list if possible, hardcoding from prev output)
  const vendorId = '550e8400-e29b-41d4-a716-446655440010'; 
  await testEndpoint('Get Vendor Details', `/vendors/${vendorId}`);
  await testEndpoint('Get Vendor Products', `/vendors/${vendorId}/products`);

  // 4. Authenticated Endpoints (User)
  const authHeaders = { 'x-user-phone': TEST_PHONE };
  
  await testEndpoint('Get User Profile', '/auth/status', 'GET', authHeaders);
  await testEndpoint('Get User Addresses', '/users/addresses', 'GET', authHeaders);
  await testEndpoint('Get User Cart', '/cart', 'GET', authHeaders);
  await testEndpoint('Get Subscriptions', '/subscriptions', 'GET', authHeaders);
  
  // 5. Error Handling Tests
  await testEndpoint('Invalid Auth', '/users/addresses', 'GET', {}, 400); // Or 401
  await testEndpoint('Invalid Route', '/foobar', 'GET', {}, 404);

  // Summary
  console.log(`\n${colors.bold}--- Test Summary ---${colors.reset}`);
  console.log(`Total Tests: ${report.passed + report.failed}`);
  console.log(`${colors.green}Passed: ${report.passed}${colors.reset}`);
  console.log(`${report.failed > 0 ? colors.red : colors.green}Failed: ${report.failed}${colors.reset}`);
  
  if (report.failed === 0) {
    console.log(`\n${colors.green}✅ All systems operational!${colors.reset}`);
  } else {
    console.log(`\n${colors.red}❌ Some systems reported errors.${colors.reset}`);
  }
}

runTests();
