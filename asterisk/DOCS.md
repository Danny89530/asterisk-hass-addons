# Home Assistant Add-on: Asterisk

## Installation

Follow these steps to get the add-on installed on your system:

1. Click here:

    [![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FTECH7Fox%2FAsterisk-add-on)

1. Scroll down the page to find the new repository, and click in the new add-on named **_Asterisk_**.
1. Click in the **_INSTALL_** button.

## Using

1. The certificate to your registered domain should already be created via the [Duck DNS](https://github.com/home-assistant/hassio-addons/tree/master/duckdns) or [Let's Encrypt](https://github.com/home-assistant/hassio-addons/tree/master/letsencrypt) add-on or another method. Make sure that the certificate files exist in the `/ssl` directory.
1. Check the add-on configuration by going to the **_Configuration_** tab. For example, you may want to change the default AMI Password to something else.
1. Start the add-on by clicking in the **_START_** button.

**Note**: _Remember to restart the add-on when the configuration is changed._

## Configuring the [Asterisk integration](https://github.com/TECH7Fox/Asterisk-integration)

- **_Host_**: `localhost`
- **_Port_**: `5038`
- **_Username_**: `admin`
- **_Password_**: whatever you set in the AMI Password configuration