# Tokenized Community Volunteer Coordination System

A comprehensive blockchain-based system for managing volunteer coordination, skill matching, scheduling, impact tracking, and recognition programs.

## System Overview

This system consists of five interconnected smart contracts that work together to create a complete volunteer coordination ecosystem:

### 1. Opportunity Matching Contract (`opportunity-matching.clar`)
- Manages volunteer opportunities and project listings
- Handles volunteer applications and matching
- Tracks opportunity status and requirements

### 2. Skill Utilization Contract (`skill-utilization.clar`)
- Manages volunteer skill profiles and organizational needs
- Matches volunteer expertise with project requirements
- Tracks skill development and utilization

### 3. Scheduling Coordination Contract (`scheduling-coordination.clar`)
- Manages volunteer availability and project timelines
- Handles scheduling conflicts and coordination
- Tracks time commitments and scheduling efficiency

### 4. Impact Tracking Contract (`impact-tracking.clar`)
- Measures volunteer contribution effectiveness
- Tracks project outcomes and volunteer performance
- Generates impact reports and metrics

### 5. Recognition Program Contract (`recognition-program.clar`)
- Manages volunteer recognition and achievements
- Issues badges, certificates, and rewards
- Tracks volunteer service history and milestones

## Key Features

- **Decentralized Coordination**: All volunteer activities are managed on-chain
- **Skill-Based Matching**: Advanced algorithms match volunteers with suitable opportunities
- **Impact Measurement**: Comprehensive tracking of volunteer contributions and outcomes
- **Recognition System**: Token-based rewards and achievement tracking
- **Transparent Scheduling**: Open and fair scheduling system for all participants

## Token Economics

The system uses native STX tokens and custom volunteer tokens (VOL) for:
- Staking requirements for opportunity creation
- Rewards for successful volunteer completion
- Recognition tokens for achievements
- Governance participation rights

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Install dependencies: \`npm install\`
3. Run tests: \`npm test\`
4. Deploy contracts: \`clarinet deploy\`

### Usage

1. **Organizations**: Create volunteer opportunities with required skills and time commitments
2. **Volunteers**: Register skills, apply for opportunities, and track your impact
3. **Coordinators**: Manage schedules, track progress, and issue recognition

## Contract Interactions

Each contract maintains its own state while providing interfaces for coordination:

- Opportunities can reference skill requirements
- Scheduling integrates with opportunity timelines
- Impact tracking measures outcomes across all activities
- Recognition rewards are based on verified contributions

## Testing

The system includes comprehensive tests using Vitest:
- Unit tests for each contract function
- Integration tests for cross-contract workflows
- Performance tests for scalability

Run tests with: \`npm test\`

## Security Considerations

- All functions include proper authorization checks
- Input validation prevents malicious data
- State transitions are atomic and consistent
- Emergency pause functionality for critical issues

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request with detailed description

## License

MIT License - see LICENSE file for details
