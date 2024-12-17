<#
.SYNOPSIS
The Resource Allocator will randomly select an engineer in the Solutions Engineering team who is skilled in a particular technology 
.DESCRIPTION 
The Resource Allocator uses data from the Product Based skill matrix to randomly select a skills match for an order
.PARAMETER skill
Use tab completion to select the skill required from the list
.EXAMPLE
.\Resource-Allocator.ps1 -skill MSSQL
.NOTES
version : 1.0.0
last updated: 02/06/2021
Author: James White
.LINK
Skills Matrix: https://pulsant.sharepoint.com/:x:/s/Delivery/Efdg4SP14RFFg0c44-dGGYkBGLDf4p5a9vaXoBh24BTSzA?e=uXBVF3
#>
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,HelpMessage="Choose the skill which you are looking for?")]
    [ValidateSet('ALertLogic','Armor','Asigra','Azure','CentOS','AnyConnect','CiscoRouters','Citrix','Cloudflare','Cpanel','DDOS','DUO','F5','HPServers','Juniper','MariaDB','MSSQL','NetworkPortfolio','Office365','vASA','PEC','Redhat','Ubuntu','Veeam','PrivateCloud','Webroot','WindowsStorageEx','Zerto')]
    [string]$skill
)

switch ( $skill )
    {
        AlertLogic        { [array]$Resources = "Ajay","MikeN","Rory","MichaelW","AndyR"                                             }
        Armor             { [array]$Resources = "Ryan","Ajay","MikeN","Rory","Martin","AndyR","Lewis"                                }
        Asigra            { [array]$Resources = "Ryan","Ajay","MikeN","Rory","Martin","AndyR","Lewis"                                }
        Azure             { [array]$Resources = "MikeN","MichaelW"                                                                   }
        CentOS            { [array]$Resources = "MikeN","Rory","MichaelW","Martin","AndyR"                                           }
        AnyConnect        { [array]$Resources = "Jim","Scott","Paul","Ryan","Ajay","Rory"                                            }
        CiscoRouters      { [array]$Resources = "Jim","Scott","Paul","AndyR"                                                         }
        CiscoSwitches     { [array]$Resources = "Jim","Scott","Paul","Ryan","Ajay"                                                   }
        Citrix            { [array]$Resources = "AndyJ"                                                                              }
        Cloudflare        { [array]$Resources = "Jim","MikeN","Martin","Rory"                                                        }
        cPanel            { [array]$Resources = "MikeN","MichaelW"                                                                   }
        DDOS              { [array]$Resources = "Jim","Ryan","Ajay","Rory","Martin"                                                  }
        DUO               { [array]$Resources = "Scott","Paul"                                                                       }
        F5                { [array]$Resources = "Ajay","MikeN"                                                                       }
        HPServers         { [array]$Resources = "Ryan","Ajay","MichaelW","Martin","AndyR","Lewis"                                    }
        Juniper           { [array]$Resources = "Jim","Scott"                                                                        }
        MariaDB           { [array]$Resources = "MikeN"                                                                              }
        MSSQL             { [array]$Resources = "Ryan","Ajay","Rory","AndyJ","AndyR","Lewis"                                         }
        NetworkPortfolio  { [array]$Resources = "Jim","Scott","Paul","AndyR"                                                         }
        Office365         { [array]$Resources = "Scott","Rory","MichaelW","Lewis"                                                    }
        vASA              { [array]$Resources = "Scott","Paul","Ryan","Ajay","MikeN","Rory","Martin","AndyJ,AndyR"                   }
        PEC               { [array]$Resources = "Ryan","Ajay","MikeN","Rory","Martin","AndyJ","AndyR","Lewis"                        }
        pASA              { [array]$Resources = "Jim","Scott","Paul","Ryan","Ajay","MikeN","Rory","Martin","AndyR"                   }
        Redhat            { [array]$Resources = "Ryan","Rory","Martin","AndyR"                                                       }
        Ubuntu            { [array]$Resources = "Ryan","MikeN","Rory","Martin","AndyR"                                               }
        Veeam             { [array]$Resources = "Ryan","Ajay","MikeN","Rory","MichaelW","Martin","AndyR"                             }
        PrivateCloud      { [array]$Resources = "Ryan","Ajay","MikeN","Rory","Martin","AndyR"                                        }
        Webroot           { [array]$Resources = "AndyR","Lewis"                                                                      }
        WindowsStorageEx  { [array]$Resources = "Ryan","Ajay","MikeN","Rory","MichaelW","Martin","AndyJ","AndyR","Lewis"             }
        Zerto             { [array]$Resources = "Ryan","Ajay","MikeN","Rory","Martin","AndyR"}
    }

Get-Random -InputObject $Resources