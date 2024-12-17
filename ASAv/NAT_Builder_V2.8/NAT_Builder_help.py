import tkinter as tk
import webbrowser


def helppage():

    root = tk.Toplevel()
    root.grab_set() #means user cannot touch mainwindow while viewing help

    ### CSV IMPORT HELP SECTION ###

    csv_help_title = tk.Label(root,text="CSV Import")
    csv_help_title.config(font=("",10,"bold"))
    csv_help_title.place(relx=0.02,rely=0.02)

    csv_help_text = "CSV import allows you to quickly import the IPs set in the VM Deployment Script CSV (Note this is the only\nCSV compatible).\
 Either select the CSV using the 3 dots or paste the path in before clicking 'Import CSV'."
    
    csv_help_desc = tk.Label(root,text=csv_help_text,justify="left")
    csv_help_desc.place(relx=0.02,rely=0.07)

    ### MANUAL IMPORT HELP SECTION ###

    manual_help_title = tk.Label(root,text="Manual Import")
    manual_help_title.config(font=("",10,"bold"))
    manual_help_title.place(relx=0.02,rely=0.15)

    manual_help_text = "Manual Import allows you to enter the IPs manually in order to create the NAT rules, to do this enter the\nInside & Public IPs in the correct boxes\
 aswell as setting the correct interfaces before clicking 'Add NAT'.\nYou can now enter range of addresses as long as they are in the same /24 network for example\n'172.22.10.10-172.22.10.15'."
    
    manual_help_desc = tk.Label(root,text=manual_help_text,justify="left")
    manual_help_desc.place(relx=0.02,rely=0.20)

    ### BUILD NAT HELP SECTION ###

    buildnat_help_title = tk.Label(root,text="Build NAT Button")
    buildnat_help_title.config(font=("",10,"bold"))
    buildnat_help_title.place(relx=0.02,rely=0.34)

    buildnat_help_text = "The 'Build NAT' button is used to build the config from the NAT rules in the table, ensure you have added\nthe NAT rules needed and they are correct\
 before proceeding with the config build."

    buildnat_help_desc = tk.Label(root,text=buildnat_help_text,justify="left")
    buildnat_help_desc.place(relx=0.02,rely=0.39)

    ### CHECK IPS HELP SECTION ###

    checkips_help_title = tk.Label(root,text="Check IPs Button")
    checkips_help_title.config(font=("",10,"bold"))
    checkips_help_title.place(relx=0.02,rely=0.47)

    checkips_help_text = "The 'Check IPs' button is used to check the IPs for the NAT rules in the table against the firewall, This will run\na range of show commands\
 we use to do these checks against the firewall and return the results.\nEnsure you have the table populated with the IPs you want to check before proceeding."

    checkips_help_desc = tk.Label(root,text=checkips_help_text,justify="left")
    checkips_help_desc.place(relx=0.02,rely=0.52)

    ### Deploy Rules HELP SECTION ###

    deploy_help_title = tk.Label(root,text="Deploy Rules Button")
    deploy_help_title.config(font=("",10,"bold"))
    deploy_help_title.place(relx=0.02,rely=0.63)
    

    deploy_help_text = "The 'Deploy Rules' button is used to deploy the rules you have created to the firewall, this button will be\ngreyed out until you have run the IP checks\
 once the IP checks are run the button will become avaliable.\nHowever, before you can deploy the rules you will need to build the config with the 'Build NAT' button.\nPlease ensure you\
 are happy before deploying any config."

    deploy_help_desc = tk.Label(root,text=deploy_help_text,justify="left")
    deploy_help_desc.place(relx=0.02,rely=0.68)

    docs_link = tk.Label(root,text="Click here to open full documentation in SharePoint")
    docs_link.config(font=("",10,"bold"))
    docs_link.place(relx=0.02,rely=0.84)
    docs_link.bind("<Button-1>", lambda e: webbrowser.open_new("https://mist.pulsant.com/tickets/?view=sectvhc"))



    root.title("Help")
    root.geometry("600x500")
    root.mainloop()



if __name__ == "__main__": #this won't be run if imported as module
    helppage()