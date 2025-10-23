# 🌾 CropGuard - Automated Crop Insurance

🚀 **Smart contract-based crop insurance that automatically pays out claims based on real-world oracle data**

## 📋 Overview

CropGuard is a decentralized crop insurance platform built on Stacks blockchain using Clarity smart contracts. It enables farmers to purchase insurance policies and receive automatic payouts when weather conditions or crop yields fall below specified thresholds.

## 🎯 Key Features

- 🛡️ **Automated Claims Processing** - No manual intervention required
- 🌤️ **Weather-Based Triggers** - Rainfall, temperature, and humidity monitoring  
- 📊 **Yield-Based Coverage** - Protection against low crop yields
- 🔄 **Oracle Integration** - Real-time agricultural data feeds
- 💰 **Instant Payouts** - Automatic STX transfers when conditions are met
- 📱 **Policy Management** - Purchase, cancel, and track policies

## 🏗️ Contract Architecture

### Core Components

- **Policy Management** - Store and manage farmer insurance policies
- **Oracle System** - Receive and validate external agricultural data
- **Claims Engine** - Automatically process claims based on trigger conditions
- **Fund Management** - Handle premium payments and claim payouts

### Key Data Structures

- `policies` - Farmer insurance policy details
- `claims` - Filed insurance claims and their status  
- `oracle-data` - Weather and yield data from authorized oracles
- `authorized-oracles` - Approved data providers

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX tokens
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/Crop-Insurance-Automation
cd Crop-Insurance-Automation
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📖 Usage Guide

### 👨‍🌾 For Farmers

#### Purchase Insurance Policy

```clarity
(contract-call? .CropGuard purchase-policy
  "corn"          ;; crop-type
  u50000000       ;; coverage-amount (50 STX)
  u5000000        ;; premium-amount (5 STX)
  404000          ;; latitude
  -740000         ;; longitude
  u8000           ;; yield-threshold (80 bushels/acre)
  u500            ;; weather-threshold (5mm rainfall)
)
```

#### File Insurance Claim

```clarity
(contract-call? .CropGuard file-claim)
```

#### Check Policy Status

```clarity
(contract-call? .CropGuard get-policy 'ST1FARMER123...)
```

#### Cancel Policy (50% refund)

```clarity
(contract-call? .CropGuard cancel-policy)
```

### 🌐 For Oracle Providers

#### Submit Weather/Yield Data

```clarity
(contract-call? .CropGuard submit-oracle-data
  0x1234...       ;; location-hash
  25              ;; temperature (°C)
  u300            ;; rainfall (mm)
  u65             ;; humidity (%)
  u15             ;; wind-speed (km/h)
  u7500           ;; yield-estimate (bushels/acre)
)
```

### 🔧 For Contract Owner

#### Set Oracle Address

```clarity
(contract-call? .CropGuard set-oracle-address 'ST1ORACLE123...)
```

#### Fund Contract

```clarity
(contract-call? .CropGuard fund-contract u100000000)
```

## 📊 Policy Parameters

| Parameter | Description | Min/Max Values |
|-----------|-------------|----------------|
| **Coverage Amount** | Insurance payout amount | 5-100 STX |
| **Premium** | Upfront payment required | Min 1 STX |
| **Crop Type** | Type of crop being insured | 50 char limit |
| **Location** | GPS coordinates (lat/long) | Required |
| **Yield Threshold** | Minimum acceptable yield | Custom per crop |
| **Weather Threshold** | Minimum rainfall required | Custom per region |

## 🔍 Contract Functions

### Public Functions

| Function | Purpose | Access |
|----------|---------|---------|
| `purchase-policy` | Buy new insurance policy | Any farmer |
| `file-claim` | Submit insurance claim | Policy holders |
| `cancel-policy` | Cancel active policy | Policy holders |
| `submit-oracle-data` | Provide agricultural data | Authorized oracles |
| `set-oracle-address` | Configure oracle provider | Contract owner |
| `fund-contract` | Add STX to contract | Contract owner |
| `withdraw-funds` | Remove STX from contract | Contract owner |

### Read-Only Functions

| Function | Purpose |
|----------|---------|
| `get-policy` | Retrieve farmer's policy details |
| `get-claim` | Get claim information by ID |
| `get-contract-stats` | View contract statistics |
| `get-oracle-data-at` | Historical oracle data |
| `is-policy-eligible-for-claim` | Check claim eligibility |

## ⚡ Automatic Claim Processing

Claims are processed automatically when:

1. 🌧️ **Weather conditions** fall below threshold (insufficient rainfall)
2. 📉 **Crop yields** are below expected levels  
3. 📅 **Policy is active** and not expired
4. ✅ **Oracle data is verified** and recent

### Payout Conditions

- **Weather Trigger**: Rainfall < weather-threshold
- **Yield Trigger**: Actual yield < yield-threshold  
- **Either condition** can trigger a full payout

## 💼 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | NOT-AUTHORIZED | Insufficient permissions |
| u101 | POLICY-NOT-FOUND | No active policy found |
| u102 | INSUFFICIENT-FUNDS | Contract lacks funds |
| u103 | POLICY-EXPIRED | Policy outside coverage period |
| u104 | CLAIM-ALREADY-PROCESSED | Duplicate claim submission |
| u105 | INVALID-ORACLE-DATA | Oracle data unverified/missing |
| u106 | POLICY-ALREADY-EXISTS | Farmer has existing policy |
| u107 | INVALID-PREMIUM | Premium below minimum |
| u108 | INVALID-COVERAGE | Coverage outside allowed range |
| u109 | WEATHER-CONDITIONS-NOT-MET | Weather above threshold |
| u110 | YIELD-THRESHOLD-NOT-MET | Yield above threshold |

## 🛡️ Security Features

- ✅ Owner-only administrative functions
- ✅ Oracle authorization system  
- ✅ Policy expiration checks
- ✅ Duplicate claim prevention
- ✅ Fund balance validations
- ✅ Input parameter validation

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `clarinet test`
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

## 🆘 Support

- 📧 Email: support@cropguard.io
- 💬 Discord: [CropGuard Community](https://discord.gg/cropguard)
- 📚 Documentation: [docs.cropguard.io](https://docs.cropguard.io)
- 🐛 Issues: [GitHub Issues](https://github.com/your-username/Crop-Insurance-Automation/issues)

---

🌾 **Built with ❤️ for farmers worldwide** 🌍
