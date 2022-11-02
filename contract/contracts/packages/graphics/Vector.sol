// SPDX-License-Identifier: MIT

/*
 * NounsAssetProvider is a wrapper around NounsDescriptor so that it offers
 * various characters as assets to compose (not individual parts).
 *
 * Created by Satoshi Nakajima (@snakajima)
 */

pragma solidity ^0.8.6;

import "trigonometry.sol/Trigonometry.sol";
import "hardhat/console.sol";

library Vector {
  using Trigonometry for uint;

  struct Struct {
    int x; // fixed point * 0x8000
    int y; // fixed point * 0x8000
  }

  function vector(int _x, int _y) internal pure returns(Struct memory newVector) {
    newVector.x = _x * 0x8000;
    newVector.y = _y * 0x8000;
  }

  function vectorWithAngle(int _angle, int _radius) internal pure returns(Struct memory newVector) {
    uint angle = uint(_angle); // + (0x4000 << 64));
    newVector.x = _radius * angle.cos();
    newVector.y = _radius * angle.sin();
  }

  function div(Struct memory _vector, int _value) internal pure returns(Struct memory newVector) {
    newVector.x = _vector.x / _value;
    newVector.y = _vector.y / _value;
  }

  function mul(Struct memory _vector, int _value) internal pure returns(Struct memory newVector) {
    newVector.x = _vector.x * _value;
    newVector.y = _vector.y * _value;
  }

  function add(Struct memory _vector, Struct memory _vector2) internal pure returns(Struct memory newVector) {
    newVector.x = _vector.x + _vector2.x;
    newVector.y = _vector.y + _vector2.y;
  }

  function rotate(Struct memory _vector, int _angle) internal pure returns(Struct memory newVector) {
    uint angle = uint(_angle); // + (0x4000 << 64));
    int cos = angle.cos();
    int sin = angle.sin();
    newVector.x = (cos * _vector.x - sin * _vector.y) / 0x8000;
    newVector.y = (sin * _vector.x + cos * _vector.y) / 0x8000;
  }
}