// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StewardCompensation is Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct Recipient {
        uint256 monthlyAmount;
        string role;
        bool isActive;
    }

    struct PaymentPeriod {
        uint256 dueTimestamp;
        bool paid;
        mapping(address => bool) recipientPaid;
    }

    IERC20 public immutable USDC;
    uint256 public constant MAX_MONTHLY_AMOUNT = 10_000e6; // 10,000 USDC

    mapping(uint256 => PaymentPeriod) public paymentPeriods;
    mapping(address => Recipient) public recipients;
    address[] public recipientList;

    event RecipientAdded(
        address indexed recipient,
        uint256 monthlyAmount,
        string role
    );
    event RecipientUpdated(
        address indexed recipient,
        uint256 newAmount,
        string role
    );
    event RecipientRemoved(address indexed recipient);
    event CompensationPaid(
        uint256 indexed periodId,
        address indexed recipient,
        uint256 amount,
        string role,
        uint256 termNumber
    );
    event PeriodInitialized(uint256 indexed periodId, uint256 dueTimestamp);

    constructor(address _usdc, address _initialOwner) {
        USDC = IERC20(_usdc);
        _transferOwnership(_initialOwner);
    }

    function addRecipient(
        address _recipient,
        uint256 _monthlyAmount,
        string calldata _role
    ) external onlyOwner {
        require(_recipient != address(0), "Invalid address");
        require(
            _monthlyAmount > 0 && _monthlyAmount <= MAX_MONTHLY_AMOUNT,
            "Invalid amount"
        );
        require(!recipients[_recipient].isActive, "Already active");

        recipients[_recipient] = Recipient({
            monthlyAmount: _monthlyAmount,
            role: _role,
            isActive: true
        });
        recipientList.push(_recipient);

        emit RecipientAdded(_recipient, _monthlyAmount, _role);
    }

    function updateRecipient(
        address _recipient,
        uint256 _newAmount,
        string calldata _role
    ) external onlyOwner {
        require(recipients[_recipient].isActive, "Recipient not active");
        require(
            _newAmount > 0 && _newAmount <= MAX_MONTHLY_AMOUNT,
            "Invalid amount"
        );

        recipients[_recipient].monthlyAmount = _newAmount;
        recipients[_recipient].role = _role;
        emit RecipientUpdated(_recipient, _newAmount, _role);
    }

    function removeRecipient(address _recipient) external onlyOwner {
        require(recipients[_recipient].isActive, "Recipient not active");

        recipients[_recipient].isActive = false;
        emit RecipientRemoved(_recipient);
    }

    function setPeriod(
        uint256 _periodId,
        uint256 _dueTimestamp
    ) external onlyOwner {
        require(
            _dueTimestamp > block.timestamp,
            "Due timestamp must be future"
        );

        PaymentPeriod storage period = paymentPeriods[_periodId];
        require(!period.paid, "Period already paid");

        period.dueTimestamp = _dueTimestamp;
        emit PeriodInitialized(_periodId, _dueTimestamp);
    }

    function sendComp(
        uint256 _periodId,
        address[] calldata _recipientsToProcess,
        uint256 _termNumber
    ) external whenNotPaused {
        PaymentPeriod storage period = paymentPeriods[_periodId];
        require(!period.paid, "Period fully paid");
        require(block.timestamp >= period.dueTimestamp, "Too early");

        bool allPaid = true;

        // Heads up! This nested loop is only okay for our small crew of stewards,
        // but would get expensive real quick if we had 20+ people to pay.
        // Future maintainer: you might want to refactor if the payment number grows.

        // Process specified recipients
        for (uint i = 0; i < _recipientsToProcess.length; i++) {
            address recipient = _recipientsToProcess[i];
            Recipient memory recipientData = recipients[recipient];

            if (recipientData.isActive && !period.recipientPaid[recipient]) {
                period.recipientPaid[recipient] = true;
                USDC.safeTransferFrom(
                    owner(),
                    recipient,
                    recipientData.monthlyAmount
                );
                emit CompensationPaid(
                    _periodId,
                    recipient,
                    recipientData.monthlyAmount,
                    recipientData.role,
                    _termNumber
                );
            }

            // Check if any active recipients remain unpaid
            for (uint j = 0; j < recipientList.length; j++) {
                if (
                    recipients[recipientList[j]].isActive &&
                    !period.recipientPaid[recipientList[j]]
                ) {
                    allPaid = false;
                    break;
                }
            }
        }

        if (allPaid) {
            period.paid = true;
        }
    }

    // View functions
    function getActiveRecipients()
        external
        view
        returns (
            address[] memory addresses,
            uint256[] memory amounts,
            string[] memory roles
        )
    {
        uint256 activeCount = 0;
        for (uint i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]].isActive) {
                activeCount++;
            }
        }

        addresses = new address[](activeCount);
        amounts = new uint256[](activeCount);
        roles = new string[](activeCount);

        uint256 j = 0;
        for (uint i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]].isActive) {
                addresses[j] = recipientList[i];
                amounts[j] = recipients[recipientList[i]].monthlyAmount;
                roles[j] = recipients[recipientList[i]].role;
                j++;
            }
        }
    }

    function getPaymentHistory(
        address recipient
    )
        public
        view
        returns (
            uint256[] memory periodIds,
            uint256[] memory amounts,
            uint256[] memory timestamps,
            bool[] memory paymentStatus
        )
    {
        // Count valid periods
        uint256 count = 0;
        for (uint256 i = 1; i <= 100; i++) {
            // Arbitrary limit for gas
            if (paymentPeriods[i].dueTimestamp != 0) {
                count++;
            }
        }

        // Initialize arrays
        periodIds = new uint256[](count);
        amounts = new uint256[](count);
        timestamps = new uint256[](count);
        paymentStatus = new bool[](count);

        // Fill arrays
        uint256 index = 0;
        for (uint256 i = 1; i <= 100 && index < count; i++) {
            if (paymentPeriods[i].dueTimestamp != 0) {
                periodIds[index] = i;
                amounts[index] = recipients[recipient].monthlyAmount;
                timestamps[index] = paymentPeriods[i].dueTimestamp;
                paymentStatus[index] = paymentPeriods[i].recipientPaid[
                    recipient
                ];
                index++;
            }
        }
    }

    // Add this function before the emergency functions
    function checkAllowance() public view returns (uint256) {
        return USDC.allowance(owner(), address(this));
    }

    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
