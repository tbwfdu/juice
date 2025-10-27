---
layout: page
title: FAQs
include_in_header: true
order: 3
---

# Frequently Asked Questions
{: .no_toc }

## Page Contents
{: .no_toc .text-delta }

* TOC
{:toc}




### How often is the Juice Database updated?
Juice has a corresponding Web Service that automatically obtains the latest list of source applications and generates an updated database **daily** at approx. 00:05 UTC.
When querying for database updates in Juice, the application communicates with this Web Service API to check for the updated database file and then replaces the local copy.

### What Operating Systems does Juice support?
The Juice application itself currently supports macOS 13+ on Apple Silicon. An x86 compatible build will available soon.

Applications that Juice can *upload* to Workspace ONE is whatever version/format/architecture the Software Vendor provides in their manifests. As long as it is supported by Workspace ONE and provided in the correct format, Juice will upload it to the Catalog.  

### Where do I get help or support if something isn't working?

[Raise an issue here](https://github.com/tbwfdu/Juice/issues) and I will get back you as soon as I can 🐛.

### What is the source of Application Information in the Juice Database?

The Juice database is populated by a separate microservice that downloads Homebrew Casks list from the **Official** Homebrew repository. This cask file is parsed, correlated and imported into the database that Juice uses.

Each day, the service pulls the latest manifests from the Homebrew repository and generates a new database. This is then made available via a webhost that Juice queries to get a copy of the updated database (if its newer than its current one).

Any application binaries, metadata, information etc. is the exact same information that Homebrew uses. This is provided by the Software Vendor and vetted by Homebrew before being added to their cask list, however Juice nor Homebrew grant any licenses, ownership or responsibility for the applications obtained or installed.

### What is the source of Recipes in the Juice Database?

Using the same microservice that downloads Application Information, Juice also automatically downloads recipes from the following AutoPkg recipe repositories on GitHub:

- [dataJAR-recipes](https://github.com/autopkg/dataJAR-recipes)
- [hansen-m-recipes](https://github.com/autopkg/hansen-m-recipes)
- [autopkg](https://github.com/autopkg/recipes)
- [hjuutilainen-recipes](https://github.com/autopkg/hjuutilainen-recipes)
- [nmcspadden-recipes](https://github.com/autopkg/nmcspadden-recipes)
- [grahampugh-recipes](https://github.com/autopkg/grahampugh-recipes)
- [rtrouton-recipes](https://github.com/autopkg/rtrouton-recipes)
- [homebysix-recipes](https://github.com/autopkg/homebysix-recipes)

Each day, the service pulls any changes to the recipes, adds them to the database, and are then correlated to the Application List to find matches.