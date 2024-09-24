import os
import json
import json5
import re
import argparse

def read_file(file_path):
    with open(file_path, 'r') as file:
        return file.read()

def apply_remappings(import_path, remappings):
    for prefix, target in remappings:
        if import_path.startswith(prefix):
            return import_path.replace(prefix, target, 1)
    return import_path

def get_imports(file_content):
    import_pattern = re.compile(r'import\s+(?:(?:["\']([^"\']+)["\'])|(?:{[^}]*}\s+from\s+["\']([^"\']+)["\']));')
    matches = import_pattern.findall(file_content)
    # Extract the import paths from the matches
    imports = [match[0] if match[0] else match[1] for match in matches]
    return imports

def get_all_dependencies(contract_path, main_contract, remappings):
    def recursive_find_dependencies(file_path, sources, visited):
        if file_path in visited:
            return
        visited.add(file_path)
        file_content = read_file(file_path)
        cwd = os.path.abspath(".") + "/"
        clean_path = file_path.replace(cwd, "")
        clean_path = clean_path.replace("node_modules/", "")
        sources[clean_path] = {"content": file_content}
        imports = get_imports(file_content)
        print("IMPORTS", clean_path, imports)
        for import_path in imports:
            mapped_import_path = apply_remappings(import_path, remappings)
            absolute_import_path = os.path.abspath(os.path.normpath(os.path.join(os.path.dirname(file_path), mapped_import_path)))
            if os.path.exists(absolute_import_path):
                print("imported ", import_path)
                recursive_find_dependencies(absolute_import_path, sources, visited)
            else:
                print(f"Warning: Import {import_path} not found.", absolute_import_path)

    sources = {}
    visited = set()
    main_contract_path = os.path.join(contract_path, main_contract)
    recursive_find_dependencies(main_contract_path, sources, visited)
    return sources

def get_hardhat_config(config_path):
    with open(config_path, 'r') as f:
        return json5.load(f)

def parse_remappings(remappings):
    parsed_remappings = []
    for remapping in remappings:
        prefix, target = remapping.split('=')
        parsed_remappings.append((prefix, os.path.abspath(target) + "/"))
    return parsed_remappings

def generate_standard_input_json(contract_path, config_path, main_contract):
    hardhat_config = get_hardhat_config(config_path)
    remappings = parse_remappings(hardhat_config.get('remappings', []))
    sources = get_all_dependencies(contract_path, main_contract, remappings)
    hardhat_config = get_hardhat_config(config_path)

    optimizer_settings = hardhat_config['solidity']['settings']['optimizer']
    evm_version = hardhat_config['solidity']['settings'].get('evmVersion', 'istanbul')

    libraries = {}
    if 'libraries' in hardhat_config['solidity']['settings']:
        libraries = hardhat_config['solidity']['settings']['libraries']

    remappings = []
    if 'remappings' in hardhat_config:
        remappings = hardhat_config['remappings']

    standard_input_json = {
        "language": "Solidity",
        "sources": sources,
        "settings": {
            "optimizer": optimizer_settings,
            "evmVersion": evm_version,
            "outputSelection": {
                "*": {
                    "*": [
                        "abi",
                        "evm.bytecode",
                        "evm.deployedBytecode",
                        "evm.methodIdentifiers"
                    ],
                    "": [
                        "ast"
                    ]
                }
            },
            "libraries": libraries,
            #"remappings": remappings
        }
    }

    return standard_input_json

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate Solidity Standard Input JSON for a specific contract file.")
    parser.add_argument("contract_file", help="The main Solidity contract file to verify, e.g., MyContract.sol")
    args = parser.parse_args()

    contract_path = "contracts"  # Path to your contracts directory
    config_path = "hardhat.config.json"  # Path to your Hardhat config file
    main_contract = args.contract_file  # Main contract file to verify

    standard_input_json = generate_standard_input_json(contract_path, config_path, main_contract)

    output_dir = os.path.join("artifacts", "standard_input", os.path.splitext(main_contract)[0])
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "standard_input.json")
    
    with open(output_path, 'w') as f:
        json.dump(standard_input_json, f, indent=4)

    print(f"Standard input JSON written to {output_path}")


