## Overview

This PR introduces two blockchain-based cognitive optimization smart contracts that work together to minimize attention fragmentation and maximize flow state productivity.

## Contracts Implemented

### 1. Context-Switch Garbage Collector (`context-switch-garbage-collector.clar`)

**Purpose:** Sweeps away mental cache eviction storms by tracking and optimizing context-switching behavior.

**Key Features:**
- Records context switch events with cognitive cost metrics (1-100 scale)
- Tracks user statistics including total switches, cumulative cognitive cost, and efficiency ratings
- Identifies high-cost switching patterns for optimization
- Awards focus restoration points based on cognitive load
- Provides session management with active/inactive states
- Calculates efficiency ratings based on average switching costs

**Public Functions:**
- `record-context-switch` - Log a context switch with cognitive cost
- `claim-restoration-points` - Redeem earned focus restoration points
- `end-focus-session` - Complete a session and get efficiency metrics

**Read-Only Functions:**
- `get-user-stats` - Retrieve user switching statistics
- `get-switch-details` - Get specific switch event details
- `get-pattern-data` - Analyze switching patterns
- `get-global-stats` - View system-wide metrics
- `has-active-session` - Check user session status

### 2. Flow-State Preheater (`flow-state-preheater.clar`)

**Purpose:** Warms up tasks to reduce cognitive cold starts through progressive context loading.

**Key Features:**
- Creates tasks with complexity levels and context data
- Multi-phase warmup system (COLD → WARMING → HOT → FLOW)
- Tracks flow session metrics including intensity (1-10 scale) and duration
- Manages task dependencies for context preloading
- Builds momentum through consistent flow state achievements
- Records streaks and peak performance metrics

**Public Functions:**
- `create-task` - Define new task with context and complexity
- `start-warmup` - Begin task warmup sequence
- `begin-flow-session` - Start timed flow session (requires 50%+ warmup)
- `end-flow-session` - Complete session and record intensity
- `add-task-dependency` - Register dependencies for context loading
- `mark-dependency-loaded` - Track loaded dependencies

**Read-Only Functions:**
- `get-task-info` - Retrieve task details
- `get-user-task` - View user's task association
- `get-session-info` - Get flow session details
- `get-user-flow-stats` - Access user flow statistics
- `get-task-dependency` - Check dependency status
- `get-global-flow-stats` - System-wide flow metrics
- `is-ready-for-flow` - Verify task warmup completion

## Technical Details

**Language:** Clarity (Stacks blockchain)  
**Lines of Code:** 322 (context-switch-garbage-collector.clar) + 433 (flow-state-preheater.clar) = 755 lines  
**Contract Independence:** No cross-contract calls or trait dependencies  
**Testing:** All contracts pass `clarinet check` validation  

## Data Structures

Both contracts utilize efficient map-based storage for:
- User statistics and metrics
- Event tracking and history
- Pattern analysis and optimization
- Session state management

## Use Cases

1. **Developer Focus Management** - Track coding session efficiency and minimize costly interruptions
2. **Creative Work Optimization** - Warm up creative tasks for faster flow state entry
3. **Productivity Analytics** - Measure and improve attention management over time
4. **Team Performance** - Aggregate attention metrics for organizational insights

## Benefits

- **Reduced Cognitive Load:** Minimize context-switching overhead through awareness and tracking
- **Faster Flow Entry:** Progressive warmup reduces time to deep focus
- **Data-Driven Optimization:** Concrete metrics for improving attention management
- **Blockchain Permanence:** Immutable record of productivity patterns
- **Privacy-Preserving:** User-controlled data with no external dependencies

## Testing

```bash
clarinet check  # ✓ 2 contracts checked
```

All contracts validated successfully with proper syntax and type checking.

## Future Enhancements

- Integration with productivity tools (calendar, task managers)
- Analytics dashboard for visualization
- Mobile app for on-the-go tracking
- Machine learning recommendations for optimal task scheduling
- Team collaboration features

## Deployment

Contracts are ready for deployment to Stacks testnet/mainnet via Clarinet deployment tools.
