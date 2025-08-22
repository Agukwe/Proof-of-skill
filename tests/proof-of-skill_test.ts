
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test user profile creation and management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let user1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('proof-of-skill', 'create-user-profile', [
                types.ascii("john_doe"),
                types.utf8("Full-stack developer with 5 years experience"),
                types.some(types.ascii("https://johndoe.dev"))
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result, `(ok ${user1.address})`);
        
        // Check user profile was created
        let getProfile = chain.callReadOnlyFn(
            'proof-of-skill',
            'get-user-profile',
            [types.principal(user1.address)],
            deployer.address
        );
        
        assertEquals(getProfile.result.includes('john_doe'), true);
    },
});

Clarinet.test({
    name: "Test skill category creation and trusted verifier management",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let verifier1 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            // Create skill category
            Tx.contractCall('proof-of-skill', 'create-skill-category', [
                types.ascii("Web Development"),
                types.utf8("Frontend and backend web development skills")
            ], deployer.address),
            
            // Add trusted verifier
            Tx.contractCall('proof-of-skill', 'add-trusted-verifier', [
                types.principal(verifier1.address),
                types.ascii("CodeCademy Certified"),
                types.list([types.ascii("online-course"), types.ascii("certification")])
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[0].result, '(ok u1)');
        assertEquals(block.receipts[1].result, '(ok true)');
        
        // Check if verifier is trusted
        let checkVerifier = chain.callReadOnlyFn(
            'proof-of-skill',
            'is-trusted-verifier',
            [types.principal(verifier1.address)],
            deployer.address
        );
        
        assertEquals(checkVerifier.result, 'true');
    },
});

Clarinet.test({
    name: "Test skill verification workflow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let user1 = accounts.get('wallet_1')!;
        let verifier1 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            // Setup: Create category and verifier
            Tx.contractCall('proof-of-skill', 'create-skill-category', [
                types.ascii("Programming"),
                types.utf8("Programming and software development")
            ], deployer.address),
            
            Tx.contractCall('proof-of-skill', 'add-trusted-verifier', [
                types.principal(verifier1.address),
                types.ascii("Tech Academy"),
                types.list([types.ascii("bootcamp"), types.ascii("assessment")])
            ], deployer.address),
            
            // Create user profile
            Tx.contractCall('proof-of-skill', 'create-user-profile', [
                types.ascii("jane_dev"),
                types.utf8("Software developer"),
                types.none()
            ], user1.address)
        ]);
        
        assertEquals(block.receipts.length, 3);
        
        // Verify a skill
        let block2 = chain.mineBlock([
            Tx.contractCall('proof-of-skill', 'verify-user-skill', [
                types.principal(user1.address),
                types.ascii("JavaScript"),
                types.uint(1), // category-id
                types.ascii("bootcamp"),
                types.uint(85),
                types.some(types.ascii("https://certificate.url")),
                types.none() // no expiration
            ], verifier1.address)
        ]);
        
        assertEquals(block2.receipts.length, 1);
        assertEquals(block2.receipts[0].result, '(ok u1)');
        
        // Check verification was created
        let getVerification = chain.callReadOnlyFn(
            'proof-of-skill',
            'get-skill-verification',
            [types.principal(user1.address), types.uint(1)],
            deployer.address
        );
        
        assertEquals(getVerification.result.includes('JavaScript'), true);
    },
});

Clarinet.test({
    name: "Test job posting and application workflow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        let deployer = accounts.get('deployer')!;
        let employer = accounts.get('wallet_3')!;
        let freelancer = accounts.get('wallet_1')!;
        let verifier1 = accounts.get('wallet_2')!;
        
        // Setup: Create user with verified skills
        let setupBlock = chain.mineBlock([
            Tx.contractCall('proof-of-skill', 'create-skill-category', [
                types.ascii("Web Dev"),
                types.utf8("Web development skills")
            ], deployer.address),
            
            Tx.contractCall('proof-of-skill', 'add-trusted-verifier', [
                types.principal(verifier1.address),
                types.ascii("Verifier"),
                types.list([types.ascii("certification")])
            ], deployer.address),
            
            Tx.contractCall('proof-of-skill', 'create-user-profile', [
                types.ascii("freelancer"),
                types.utf8("Experienced developer"),
                types.none()
            ], freelancer.address),
            
            Tx.contractCall('proof-of-skill', 'verify-user-skill', [
                types.principal(freelancer.address),
                types.ascii("React"),
                types.uint(1),
                types.ascii("certification"),
                types.uint(90),
                types.none(),
                types.none()
            ], verifier1.address)
        ]);
        
        assertEquals(setupBlock.receipts.length, 4);
        
        // Post a job
        let jobBlock = chain.mineBlock([
            Tx.contractCall('proof-of-skill', 'post-job', [
                types.ascii("React Developer Needed"),
                types.utf8("Looking for experienced React developer for e-commerce project"),
                types.list([types.ascii("React"), types.ascii("JavaScript")]),
                types.list([types.uint(1)]), // categories
                types.uint(100), // min reputation
                types.uint(5000), // max budget
                types.uint(chain.blockHeight + 100) // deadline
            ], employer.address)
        ]);
        
        assertEquals(jobBlock.receipts.length, 1);
        assertEquals(jobBlock.receipts[0].result, '(ok u1)');
        
        // Apply for job
        let applicationBlock = chain.mineBlock([
            Tx.contractCall('proof-of-skill', 'apply-for-job', [
                types.uint(1), // job-id
                types.utf8("I have 3 years of React experience and can deliver high-quality code"),
                types.uint(4500), // proposed budget
                types.uint(chain.blockHeight + 50) // estimated completion
            ], freelancer.address)
        ]);
        
        assertEquals(applicationBlock.receipts.length, 1);
        assertEquals(applicationBlock.receipts[0].result, '(ok true)');
        
        // Check application exists
        let getApplication = chain.callReadOnlyFn(
            'proof-of-skill',
            'get-job-application',
            [types.uint(1), types.principal(freelancer.address)],
            deployer.address
        );
        
        assertEquals(getApplication.result.includes('pending'), true);
    },
});
