# Purview Retention Policy Inventory

PowerShell automation to retrieve Microsoft Purview Retention Policy and Retention Rule details and export them to a CSV inventory.

## Flow

Microsoft Purview
        ↓
Connect-IPPSSession
        ↓
Validate Required Cmdlets
        ↓
Get-RetentionCompliancePolicy
        ↓
Get-RetentionComplianceRule
        ↓
Extract Policy and Rule Configuration
        ↓
Export to CSV
        ↓
Retention Policy Inventory Report

## Features

- Prompts for output folder
- Connects to Microsoft Purview
- Validates required Retention cmdlets
- Retrieves Retention Policies
- Retrieves associated Retention Rules
- Collects workloads and locations
- Extracts retention duration and action
- Exports results to CSV

## Output Columns

- Policy Name
- Policy Enabled
- Policy Mode
- Workloads / Locations
- Rule Name
- Rule Enabled
- Retention Duration
- Retention Action
- Expiration Date Option
- Relevant Configuration

## Requirements

- PowerShell
- ExchangeOnlineManagement module
- Microsoft Purview permissions
- Active Microsoft 365 tenant with Retention capabilities

## Usage

Run:

```powershell
& ".\Purview_Retention_Policy_Inventory.ps1"
