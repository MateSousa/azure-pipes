# Unified App Build/Deploy/Swap Pipeline Design

## Problem
Two separate pipeline files (`Build_Deploy_Swap_App_Dev.yaml` and `Build_Deploy_Swap_App.yaml`) with duplicated build/deploy/swap logic. Only difference is environment-specific variables and an extra PowerShell step in prod.

## Solution
Single pipeline file with conditional stages. Branch-based routing determines which environments are deployed.

## Pipeline Structure

```
Build → Deploy DEV → Swap DEV → Deploy PROD → Swap PROD
                                  ↑ main only    ↑ main only
                                  ↑ PROD environment approval
```

### Stages

| Stage | Runs When | Environment | Pool |
|-------|-----------|-------------|------|
| Build | Always | — | Self-Hosted |
| DeployDev | Always (depends on Build) | DEV | Self-Hosted |
| SwapDev | Always (depends on DeployDev) | — | Self-Hosted |
| DeployProd | main branch only (depends on Build) | PROD (approval) | Self-Hosted |
| SwapProd | main branch only (depends on DeployProd) | — | Self-Hosted |

### Variables
All inline, prefixed by environment (dev*/prod*). Shared: buildConfiguration=Release.

### Key Decisions
- Approach 1 chosen: single file, conditional stages, inline variables
- Environment approvals via Azure DevOps environments named `DEV` and `PROD`
- Build number injection (PowerShell) included for both environments
- DEV and PROD deploy stages both depend on Build (parallel after build)
- PROD stages gated by `refs/heads/main` condition

### Azure DevOps Setup Required
Configure approval checks: Project Settings → Environments → PROD → Approvals and checks → Add → Approvals
