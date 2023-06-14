// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title EIP712
 *
 * @author Fujidao Labs
 *
 * @notice EIP712 abstract contract for HimalayaMigrator.
 *
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and
 * signing of typed structured data.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that
 * is used as part of the encoding scheme, and the final step of the encoding to obtain
 * the message digest that is then signed via ECDSA ({_hashTypedDataV4}).
 *
 * A big part of this implementation is inspired from:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol
 *
 * The main difference with OZ is that the "chainid" is not included in the domain separator
 * but in the structHash. The rationale behind is to adapt EIP712 to cross-chain message
 * signing: allowing a user on chain A to sign a message that will be verified on chain B.
 * If we were to include the "chainid" in the domain separator, that would require the user
 * to switch networks back and forth, because of the limitation: "The user-agent should
 * refuse signing if it does not match the currently active chain.". That would serously
 * deteriorate the UX.
 *
 * Indeed, EIP712 doesn't forbid it as it states that "Protocol designers only need to
 * include the fields that make sense for their signing domain." into the the struct
 * "EIP712Domain". However, we decided to add a ref to "chainid" in the param salt. Together
 * with "chainid" in the typeHash, we assume those provide sufficient security guarantees.
 */

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

abstract contract EIP712 {
  bytes32 private constant _TYPE_HASH =
    keccak256("EIP712Domain(string name,string version,address verifyingContract,bytes32 salt)");

  /**
   * @dev Cache the domain separator as an immutable value, but also store
   * the chain id that it corresponds to, in order to invalidate the cached
   * domain separator if the chain id changes.
   */
  bytes32 private immutable _cachedDomainSeparator;
  uint256 private immutable _cachedChainId;
  address private immutable _cachedThis;

  bytes32 private constant _hashedName = keccak256(bytes("HimalayaMigrator"));
  bytes32 private constant _hashedVersion = keccak256(bytes("v0.0.1"));

  /**
   * @notice Constructor to initializes the domain separator and parameter caches.
   *
   * @dev The meaning of `name` and `version` is specified in
   * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
   * NOTE: These parameters cannot be changed except through a
   * xref:learn::upgrading-smart-contracts.adoc[smartcontract upgrade].
   */
  constructor() {
    _cachedChainId = block.chainid;
    _cachedDomainSeparator = _buildDomainSeparator(_TYPE_HASH, _hashedName, _hashedVersion);
    _cachedThis = address(this);
  }

  /**
   * @dev Returns the domain separator of this contract.
   */
  function _domainSeparatorV4() internal view returns (bytes32) {
    if (address(this) == _cachedThis && block.chainid == _cachedChainId) {
      return _cachedDomainSeparator;
    } else {
      return _buildDomainSeparator(_TYPE_HASH, _hashedName, _hashedVersion);
    }
  }

  /**
   * @dev Builds and returns domain seperator according to inputs.
   *
   * @param typeHash cached in this contract
   * @param nameHash cahed in this contract
   * @param versionHash cached in this contract
   */
  function _buildDomainSeparator(
    bytes32 typeHash,
    bytes32 nameHash,
    bytes32 versionHash
  )
    private
    view
    returns (bytes32)
  {
    return keccak256(
      abi.encode(
        typeHash, nameHash, versionHash, address(this), keccak256(abi.encode(block.chainid))
      )
    );
  }

  /**
   * @dev Given an already:
   * https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct],
   * this function returns the hash of the fully encoded EIP712 message for this domain.
   *
   * This hash can be used together with {ECDSA-recover} to obtain the signer of
   * a message. For example:
   *
   * ```solidity
   * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
   *     keccak256("Mail(address to,string contents)"),
   *     mailTo,
   *     keccak256(bytes(mailContents))
   * )));
   * address signer = ECDSA.recover(digest, signature);
   * ```
   * @param structHash of signed data
   */
  function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
    return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
  }
}