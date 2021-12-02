const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Private sale", function () {
  it("is deployable", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();
  });
  it("can retrieve latest prices", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

    expect((await private_sale.getLatestPrice())[0]).to.equal(62322000000);
  });
  it("does not own BNB", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

    expect(await ethers.utils.formatEther(
		await ethers.provider.getBalance(private_sale.address)
	)).to.equals("0.0")
  });
  it("refuses small balances", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	let owner = await ethers.getSigner()
	const tx = owner.sendTransaction({
		to: private_sale.address,
		value: ethers.utils.parseEther("0.9")
	})
	try {
		await tx
	}
	catch(e) {
		expect(e.message).to.equals(
			"VM Exception while processing transaction: reverted with reason string " +
			"'Private sale requires a minimum investment of 1 BNB'"
		)
	}

    expect(await ethers.utils.formatEther(
		await ethers.provider.getBalance(private_sale.address)
	)).to.equals("0.0")
  });
  it("accept exactly 1 BNB", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	let owner = await ethers.getSigner()
	const tx = owner.sendTransaction({
		to: private_sale.address,
		value: ethers.utils.parseEther("1.0")
	})
	await tx

    expect(await ethers.utils.formatEther(
		await ethers.provider.getBalance(private_sale.address)
	)).to.equals("1.0")
  });
  it("increase the released amount", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	let owner = await ethers.getSigner()
	const tx = owner.sendTransaction({
		to: private_sale.address,
		value: ethers.utils.parseEther("1.0")
	})
	await tx

    expect(await ethers.utils.formatEther(
		await private_sale.released()
	)).to.equals("49994928.8")
  });
  it("stops at cap", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	let owner = await ethers.getSigner()
	const tx = owner.sendTransaction({
		to: private_sale.address,
		value: ethers.utils.parseEther("2.0")
	})
	await tx

    expect(await ethers.utils.formatEther(
		await private_sale.released()
	)).to.equals("50000000.0")
  });
  it("refunds exceeding", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	let owner = await ethers.getSigner()
	const tx = owner.sendTransaction({
		to: private_sale.address,
		value: ethers.utils.parseEther("2.0")
	})
	await tx

    expect(await ethers.utils.formatEther(
		await ethers.provider.getBalance(private_sale.address)
	)).to.equals("1.203427361124482527")
  });
  it("can release funds", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	let owner = await ethers.getSigner()
	const tx = owner.sendTransaction({
		to: private_sale.address,
		value: ethers.utils.parseEther("2.0")
	})
	await tx

    let contract_funds = await ethers.utils.formatEther(
		await ethers.provider.getBalance(private_sale.address)
	)
	
	await private_sale.release()

	expect(await ethers.utils.formatEther(
		await ethers.provider.getBalance("0x01Af10f1343C05855955418bb99302A6CF71aCB8")
	)).to.equals(contract_funds)
  });
  it("can update max release", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	let max_release = await ethers.utils.formatEther(
		await private_sale.maxRelease()
	)

	await private_sale.updateMaxRelease(
		ethers.utils.parseEther("123456789.0")
	)

	expect(await ethers.utils.formatEther(
		await private_sale.maxRelease()
	)).to.equals("123456789.0")
  });
  it("is ICO end correct", async function () {
    const PrivateSale = await ethers.getContractFactory("TestablePrivateSale");
    const private_sale = await PrivateSale.deploy();
    await private_sale.deployed();

	expect(
		await private_sale.ICO_END()
	).to.equals("1648771199")
  });
});
