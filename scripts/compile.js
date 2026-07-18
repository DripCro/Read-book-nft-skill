const fs = require('fs');
const path = require('path');
const solc = require('solc');
const { keccak256, toBytes, encodeAbiParameters, getContractAddress } = require('viem');

// Set OWNER to the wallet that will own the collection (only it can mint).
const OWNER = (process.env.OWNER || '0x35f3563c4bfc804bf60568bd7d2436d58be8064f').toLowerCase();
const PROXY = '0x4e59b44847b379578588920cA78FbF26c0B4956C'; // canonical deterministic-deployment-proxy

const SOURCE_PATH = path.join(__dirname, '..', 'contracts', 'ReadBooks.sol');
const source = fs.readFileSync(SOURCE_PATH, 'utf8');

function findImports(importPath) {
  const candidates = [
    path.join(process.cwd(), 'node_modules', importPath),
    path.join(__dirname, '..', 'node_modules', importPath),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return { contents: fs.readFileSync(c, 'utf8') };
  }
  return { error: 'File not found: ' + importPath };
}

const input = {
  language: 'Solidity',
  sources: { 'ReadBooks.sol': { content: source } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object'] } },
  },
};

const out = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));
const errors = (out.errors || []).filter((e) => e.severity === 'error');
if (errors.length) {
  console.error(errors.map((e) => e.formattedMessage).join('\n'));
  process.exit(1);
}

const contract = out.contracts['ReadBooks.sol']['ReadBooks'];
const bytecode = '0x' + contract.evm.bytecode.object;
const ctorArgs = encodeAbiParameters([{ type: 'address' }], [OWNER]);
const initcode = bytecode + ctorArgs.slice(2);
const salt = keccak256(toBytes('read-books-v1-' + OWNER));

const predicted = getContractAddress({ opcode: 'CREATE2', from: PROXY, salt: salt, bytecode: initcode });
const payload = salt + initcode.slice(2);

console.log('PREDICTED_ADDRESS=' + predicted);
console.log('SALT=' + salt);
console.log('INITCODE_BYTES=' + (initcode.length - 2) / 2);
console.log('PAYLOAD_BYTES=' + (payload.length - 2) / 2);
fs.writeFileSync('deploy-payload.txt', payload);
console.log('payload written to deploy-payload.txt');
