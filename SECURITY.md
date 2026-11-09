# Security policy

## Report a problem privately

If you find a security problem (for example a leaked key or credential, personal data in the repository, or a way to make the tool run attacker-supplied code), do not open a public issue.

Use GitHub's private report: on the repository page, open the **Security** tab and choose **Report a vulnerability**. If that button is missing, the maintainers have not turned it on yet; open a public issue that says only "I have a security report, please contact me", with no details, and a maintainer will arrange a private channel. The repository owner is not yet named; this file will name a contact when one is chosen.

## Keep secrets out of issues and commits

- Never paste API keys, tokens, passwords or `.Renviron` contents into an issue, pull request or comment. Issues here are public.
- Do not include names, emails, phone numbers or anything about real people. Grant and agency names are fine.
- If you committed a key by mistake, tell the maintainers privately and revoke the key at its provider first. Deleting the commit does not make the key safe.

## What the tool does with data

The tool is a static web page. It loads one data file from its own site and keeps your Pursue, Maybe and Skip marks and notes in your browser only. It has no accounts and no server of its own.

## Scope

Please report problems in this repository's code, workflows and committed data. Problems in Grants.gov, SAM.gov, GitHub or other outside services belong to those services.
