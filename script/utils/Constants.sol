// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

contract Constants {
    address constant APOTHEM = 0x309dE78df92208FABFa2F8202efb8395Ee20890D;
    address constant COSTON = 0x1263356C4f6278210B8ae900c7Ab749550bFbc8e;

    address constant APOTHEM_MULTISIG =
        0x6aE9B98Cb0bfe5FBB5659d77c6c6249225639617;
    address constant COSTON_MULTISIG =
        0x790A87F4Be79A00A65F879aA0B8D25074fD42110;

    address constant WXDC_APOTHEM = 0xE99500AB4A413164DA49Af83B9824749059b46ce;
    address constant WXDC_COSTON = 0x2460Ebd7b0a4B019ebCE6bcF5a2F213BCdF10f48;

    address[] validators = new address[](5);
    address[] validatorFeeRecipients = new address[](5);
    bool[] isFirstCommittees = new bool[](5);

    string[5] VALIDATOR_STATUS = [
        "Uninitialized",
        "Removed",
        "FirstCommittee",
        "SecondCommittee"
    ];

    uint16 constant PROTOCOL_FEES = 50;

    constructor() {
        uint16 index = 0;

        // Common Prefix
        validators[index] = 0x5f35A050dcBCC54F17F53EF116f16c4f4a8663de;
        validatorFeeRecipients[
            index
        ] = 0x0e06d7f60Ac1D71492436F1EB1880E7FE47373Cc;
        isFirstCommittees[index] = true;

        index++;

        // FLR Finance
        validators[index] = 0x0eF84bF426C814240414497f5131B7f9e808a17A;
        validatorFeeRecipients[
            index
        ] = 0x2DD97AE3FE5665e489F09B1cc20605a31dEF42f5;
        isFirstCommittees[index] = true;

        index++;

        // Blockchain22 Networks
        validators[index] = 0x21FDC61aaFe292cf67E32a369f34cE7588B05D1b;
        validatorFeeRecipients[
            index
        ] = 0x96237903B1b2dc557c3F3a4B9FBF942DefEBF75d;
        isFirstCommittees[index] = false;

        index++;

        // Big Bro Little Bro Inc
        validators[index] = 0x5114fA60C3A0f386da9aBbfD38ad6e78Afb8d8a4;
        validatorFeeRecipients[
            index
        ] = 0xaE5886e943153f8285F93AfE144B58079dEaC927;
        isFirstCommittees[index] = false;

        index++;

        // NORTSO
        validators[index] = 0x20FDcb0063d6fDf51E38727907e43FC592aA827f;
        validatorFeeRecipients[
            index
        ] = 0xA7eA9Da13797F0965AD45CA25A3a19f9B85fb821;
        isFirstCommittees[index] = false;
    }
}
