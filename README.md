# Juice

Juice is a native macOS Application that enables Workspace ONE Administrators to easily manage the lifecycle of Internal macOS Apps in Workspace ONE UEM. Vastly different from App management from the Apple App Store, native Apps in Workspace ONE typically have a larger overhead in management.

Juice currently has a database of over **7500 applications** that are available for automatic upload into Workspace ONE UEM. In addition to this, the Juice database contains over **1300 Autopkg Recipes** that administrators can leverage alongisde Juice Apps and merge recipe metadata into parsed pkginfo.plist files for more robust app lifecycle management. These Autopkg recipes are automatically matched against applications in the database making adding missing metadata incredibly easy.

Even better, Juice also generates all of the metadata files and icons required for uploading to Workspace ONE UEM, removing the need to manually process the applications with the Workspace ONE Admin Assistant application.

<img alt="image" src="https://github.com/user-attachments/assets/4d24f5a7-79a1-4e67-957f-37405c434f4c" />


Juice simplifies the overall App Management process in Workspace ONE UEM by streamlining these 4 key processes:

 
### App Discovery

<img width="400" alt="SCR-20250825-obsy" src="https://github.com/user-attachments/assets/62d28476-6c1c-4296-88fb-06cde32fa87a" />

Juice currently has an Application Repository of approximately 7500 native macOS applications in its database that an administrator can search and with a few simple clicks can import automatically into the Workspace ONE catalog, ready for deployment. If an application has a matching Autopkg recipe available, administrators will be shown an option that allows administrators to merge recipe metadata with the generated Munki pkginfo.plist file.


### Application Update Management

<img width="400" alt="73bb3e16-c659-46b9-b9c8-9f1e970c05f8" src="https://github.com/user-attachments/assets/789711dc-46fe-4b24-9a81-dc336fc2743c" />

Juice can interrogate the existing catalog of native macOS Applications in Workspace ONE UEM and identify any available application updates. If an update to an Application is available in the Juice database, Workspace ONE administrators can select the updated application and automatically upload this to the Workspace ONE UEM Application Catalog.


### Bulk Download for Offline Vulnerability Scanning

<img width="400" alt="SCR-20250825-ocnc" src="https://github.com/user-attachments/assets/c4a227aa-e483-4910-bc86-237d03701926" />

After nearly 2 years of collaboration with large enterprises, it is a fundamental requirement that Applications must be scanned and validated by their own security teams. Juice allows for a two-stage process where you can download installers in bulk, have your security teams scan the files, and then import these downloaded Apps back into Juice at a later stage to do the upload into Workspace ONE.


### Bulk Import and Upload

<img width="400" alt="SCR-20250825-odnk" src="https://github.com/user-attachments/assets/0d2bef45-fd17-4def-881f-cbb79538a473" />

Prior to Juice, processing and uploading of macOS applications into Workspace ONE needed to be done individually. Now Administrators can scan an existing folder of native macOS Applications and Juice will process the installers, generate the required metadata files, extract the icons and facilitate the bulk upload of apps into the Workspace ONE App Catalog. Better yet, Juice can import your own internal applications, not only those downloaded using Juice, and will scan folders recursively for suitable installers allowing you to import your own local repositories.

## Adding or Editing Metadata

To identify which applications have available metadata, you'll see a small icon on App results in Juice.
<img width="114" height="49" alt="SCR-20250825-oevz" src="https://github.com/user-attachments/assets/bfc92c46-6171-4c29-b12d-0f1d04b149a8" />

To add any metadata from a recipe, you can do this after the application has been downloaded in Step 2 of the upload process. Simply click on the Edit button in the 'Edit Metadata and Icons' screen.

<img width="400" alt="SCR-20250825-ohar" src="https://github.com/user-attachments/assets/07b38fbb-8608-4a83-82d9-a02237a26b73" />

Once you've made any changes, you'll get a chance to review the values and if needed, view the resulting pkginfo.plist file. 

<img width="400" alt="SCR-20250825-ohso" src="https://github.com/user-attachments/assets/1fbac645-8d78-4f01-8b79-0f3bd63eb4fa" /> <img width="400" alt="SCR-20250825-ohwr" src="https://github.com/user-attachments/assets/39104801-8b78-450c-a99f-1dd5fd6c1735" />

If you 'Enable Editing', you can **directly** edit the pkginfo.plist file and add any manual metadata directly from Juice.

<img width="400" alt="SCR-20250825-oikk" src="https://github.com/user-attachments/assets/263a7393-ca46-48c9-aa18-31557fbfba1c" />

## Configuring Juice

When first running Juice you will need to enter credentials for Workspace ONE UEM. You can give your first environment a friendly name to easily identify which environment you are working with. You will need to obtain an OAuth Client ID and Client Secret from your Workspace ONE UEM tenant. Details on how to obtain those details, and which OAuth Region to use are [here](https://docs.omnissa.com/bundle/WorkspaceONE-UEM-Console-BasicsVSaaS/page/UsingUEMFunctionalityWithRESTAPI.html#create_an_oauth_client_to_use_for_api_commands_saas).

<img width="400" alt="SCR-20250825-ojqz" src="https://github.com/user-attachments/assets/a7c17d41-4ffb-45e2-b070-72da944279c0" />

Juice stores configuration in `/Users/username/.juice`. It will save any downloaded applications in `/Users/username/Juice`.

**IMPORTANT** - Juice stores your provided Client ID and Client Secret securely in the Keychain of your device.
