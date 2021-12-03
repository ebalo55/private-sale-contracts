const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("Private sale", function () {
	it("is deployable", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();
	});
	it("can retrieve latest prices", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		expect((await private_sale.getLatestPrice())[0]).to.equal(62322000000);
	});
	it("does not own BNB", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		expect(
			await ethers.utils.formatEther(
				await ethers.provider.getBalance(private_sale.address)
			)
		).to.equals("0.0");
	});
	it("refuses small balances", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let owner = await ethers.getSigner();
		const tx = owner.sendTransaction({
			to: private_sale.address,
			value: ethers.utils.parseEther("0.9"),
		});
		try {
			await tx;
		} catch (e) {
			expect(e.message).to.equals(
				"VM Exception while processing transaction: reverted with reason string " +
					"'Private sale requires a minimum investment of 1 BNB'"
			);
		}

		expect(
			await ethers.utils.formatEther(
				await ethers.provider.getBalance(private_sale.address)
			)
		).to.equals("0.0");
	});
	it("accept exactly 1 BNB", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let owner = await ethers.getSigner();
		const tx = owner.sendTransaction({
			to: private_sale.address,
			value: ethers.utils.parseEther("1.0"),
		});
		await tx;

		expect(
			await ethers.utils.formatEther(
				await ethers.provider.getBalance(private_sale.address)
			)
		).to.equals("1.0");
	});
	it("increase the released amount", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let owner = await ethers.getSigner();
		const tx = owner.sendTransaction({
			to: private_sale.address,
			value: ethers.utils.parseEther("1.0"),
		});
		await tx;

		expect(
			await ethers.utils.formatEther(await private_sale.released())
		).to.equals("49994928.8");
	});
	it("stops at cap", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let owner = await ethers.getSigner();
		const tx = owner.sendTransaction({
			to: private_sale.address,
			value: ethers.utils.parseEther("2.0"),
		});
		await tx;

		expect(
			await ethers.utils.formatEther(await private_sale.released())
		).to.equals("50000000.0");
	});
	it("refunds exceeding", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let owner = await ethers.getSigner();
		const tx = owner.sendTransaction({
			to: private_sale.address,
			value: ethers.utils.parseEther("2.0"),
		});
		await tx;

		expect(
			await ethers.utils.formatEther(
				await ethers.provider.getBalance(private_sale.address)
			)
		).to.equals("1.203427361124482527");
	});
	it("can release funds", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let owner = await ethers.getSigner();
		const tx = owner.sendTransaction({
			to: private_sale.address,
			value: ethers.utils.parseEther("2.0"),
		});
		await tx;

		let contract_funds = await ethers.utils.formatEther(
			await ethers.provider.getBalance(private_sale.address)
		);

		await private_sale.release();

		expect(
			await ethers.utils.formatEther(
				await ethers.provider.getBalance(
					"0x01Af10f1343C05855955418bb99302A6CF71aCB8"
				)
			)
		).to.equals(contract_funds);
	});
	it("can update max release", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let max_release = await ethers.utils.formatEther(
			await private_sale.maxRelease()
		);

		await private_sale.updateMaxRelease(
			ethers.utils.parseEther("123456789.0")
		);

		expect(
			await ethers.utils.formatEther(await private_sale.maxRelease())
		).to.equals("123456789.0");
	});
	it("is ICO end correct", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		expect(await private_sale.ICO_END()).to.equals("1648771199");
	});
	it("can call buy with referral", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		await private_sale.updateMaxRelease(
			ethers.utils.parseEther("61000000.0")
		);

		let already_released = await ethers.utils.formatEther(await private_sale.released());

		await private_sale.buy("non-existing", {
			value: ethers.utils.parseEther("1.0"),
		});

		expect(
			await ethers.utils.formatEther(await private_sale.released())
		).to.equals((+already_released + 24928.8).toString());
	});
	it("can add referral and checks work", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		await private_sale.updateMaxRelease(
			ethers.utils.parseEther("61000000.0")
		);

		let _now = (Date.now() / 1000 - 1) | 0,
			_2_min = (Date.now() / 1000 + 120) | 0

		await private_sale.addReferral(
			"code",
			5,
			2,
			_now,
			_2_min
		);

		let already_released = await ethers.utils.formatEther(await private_sale.released());

		await private_sale.buy("code", {
			value: ethers.utils.parseEther("1.0"),
		});

		expect(
			await ethers.utils.formatEther(await private_sale.released())
		).to.equals((+already_released + 26175.24).toString());

		await private_sale.buy("non-existing", {
			value: ethers.utils.parseEther("1.0"),
		});

		expect(
			await ethers.utils.formatEther(await private_sale.released())
		).to.equals((+already_released + 26175.24 + 24928.8).toString());
	});
	it("fails if elapsed", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);

		let _now = (Date.now() / 1000) - 1 | 0

		const private_sale = await PrivateSale.deploy(
			_now,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let owner = await ethers.getSigner();
		const tx = owner.sendTransaction({
			to: private_sale.address,
			value: ethers.utils.parseEther("1.0"),
		});
		try {
			await tx;
		} catch (e) {
			expect(e.message).to.equals(
				"VM Exception while processing transaction: reverted with reason string " +
					"'Private sale elapsed'"
			);
		}
	});
	it("can manually release funds", async function () {
		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(
			1642118399,
			"0x0000000000000000000000000000000000000000"
		);
		await private_sale.deployed();

		let already_released = await ethers.utils.formatEther(await private_sale.released());

		await private_sale.releasedManualOverride(
			ethers.utils.parseEther("123456.0")
		)
		
		expect(
			await ethers.utils.formatEther(await private_sale.released())
		).to.equals((+already_released + 123456).toString() + ".0");
	});
	it("can burn unsold", async function () {
		const Melodity = await ethers.getContractFactory("Melodity");
		const melodity = await Melodity.deploy();
		await melodity.deployed();

		let now = (Date.now() / 1000 - 1) | 0;

		const PrivateSale = await ethers.getContractFactory(
			"TestablePrivateSale"
		);
		const private_sale = await PrivateSale.deploy(now, melodity.address);
		await private_sale.deployed();

		await melodity.grantRole(
			"0x0000000000000000000000000000000000000000000000000000000000000000",
			private_sale.address
		);

		expect(await private_sale.alive_until()).to.equals(now.toString());

		expect(
			await ethers.utils.formatEther(
				await melodity.balanceOf(
					"0x0000000000000000000000000000000000000000"
				)
			)
		).to.equals("0.0");

		let supply = await ethers.utils.formatEther(
			await melodity.totalSupply()
		);

		// update max release amount to let the burn destroy some funds
		await private_sale.updateMaxRelease(
			ethers.utils.parseEther("71000000.0")
		);
		await private_sale.createSelfLock();
		await private_sale.burnUnsold();

		expect(
			await ethers.utils.formatEther(
				await melodity.balanceOf(private_sale.address)
			)
		).to.equals("0.0");

		expect(
			await ethers.utils.formatEther(
				await melodity.balanceOf(
					"0x0000000000000000000000000000000000000000"
				)
			)
		).to.equals("0.0");

		expect(
			await ethers.utils.formatEther(await melodity.totalSupply())
		).to.equals(supply);
	});
});
