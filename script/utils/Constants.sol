// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract Constants {
    address constant APOTHEM = 0x673b27A6818F7E9BDD54bF1103dB4D996aE11252;
    address constant COSTON = 0x65fD1532A09be6927121C402c6c3D7fD4a36DA1E;

    address[] validators = new address[](5);
    address[] validatorFeeRecipients = new address[](5);
    bool[] isFirstCommittee = new bool[](5);

    constructor() {
        uint16 index = 0;

        // Common Prefix
        validators[index] = 0x5f35A050dcBCC54F17F53EF116f16c4f4a8663de;
        validatorFeeRecipients[
            index
        ] = 0x0e06d7f60Ac1D71492436F1EB1880E7FE47373Cc;
        isFirstCommittee[index] = true;

        index++;

        // FLR Finance
        validators[index] = 0x0eF84bF426C814240414497f5131B7f9e808a17A;
        validatorFeeRecipients[
            index
        ] = 0x2DD97AE3FE5665e489F09B1cc20605a31dEF42f5;
        isFirstCommittee[index] = true;

        index++;

        // Blockchain22 Networks
        validators[index] = 0x21FDC61aaFe292cf67E32a369f34cE7588B05D1b;
        validatorFeeRecipients[
            index
        ] = 0x96237903B1b2dc557c3F3a4B9FBF942DefEBF75d;
        isFirstCommittee[index] = false;

        index++;

        // Big Bro Little Bro Inc
        validators[index] = 0x5114fA60C3A0f386da9aBbfD38ad6e78Afb8d8a4;
        validatorFeeRecipients[
            index
        ] = 0xaE5886e943153f8285F93AfE144B58079dEaC927;
        isFirstCommittee[index] = false;

        index++;

        // NORTSO
        validators[index] = 0x20FDcb0063d6fDf51E38727907e43FC592aA827f;
        validatorFeeRecipients[
            index
        ] = 0xA7eA9Da13797F0965AD45CA25A3a19f9B85fb821;
        isFirstCommittee[index] = false;
    }
}
