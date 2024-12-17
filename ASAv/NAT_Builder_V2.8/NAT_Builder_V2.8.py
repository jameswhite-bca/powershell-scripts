#author: Ryan Baldry
#version: 2.9
#comments:
    #Includes changes from MF Feedback (Connection status)
    #Adding in ACL changes
    #Changed external IPs checks so delays are 2 and maxloop 500 as was having timeout issues
							   							 

import tkinter as tk
from tkinter import ttk as ttk
from tkinter import messagebox
from tkinter import filedialog
import csv
import ctypes
import netmiko
from netmiko import ConnectHandler #for connecting to Cisco ASA
import NAT_Builder_help as nat_help
import ipaddress

ctypes.windll.kernel32.SetConsoleTitleW("NAT_Builder_v2.9") #setting console name

class ACLGUIPage():
    def __init__(self):

        self.ACLFrame = tk.Frame(root)
        
        #LABELS
        src_label = tk.Label(self.ACLFrame,text="Source")
        src_label.place(relx=0.1,rely=0.1)
        
        dst_label = tk.Label(self.ACLFrame,text="Destination")
        dst_label.place(relx=0.2,rely=0.1)
        
        service_label = tk.Label(self.ACLFrame,text="Service")
        service_label.place(relx=0.3,rely=0.1)
        
        line_num_label = tk.Label(self.ACLFrame,text="Line Number")
        line_num_label.place(relx=0.4,rely=0.1)
        
        act_label = tk.Label(self.ACLFrame,text="Permit/Deny")
        act_label.place(relx=0.5,rely=0.1)

        self.ACLFrame.place(x=0, y=35, relwidth=1, relheight=1)


class GUIPage():

    def __init__(self):
        self.guiframe = tk.Frame(root)
        

        self.validation = ip_validation

        #LABELS

        #csv labels
        csvTitle_label = tk.Label(self.guiframe,text="CSV Input")
        csvTitle_label.config(font=("none",12))
        csvTitle_label.place(relx=0.02,rely=0)

        csv_label = tk.Label(self.guiframe,text="CSV path: ")
        csv_label.place(relx=0.03,rely=0.05)

        #manual labels
        manualTitle_label = tk.Label(self.guiframe,text="Manual Input")
        manualTitle_label.config(font=("none",12))
        manualTitle_label.place(relx=0.02,rely=0.1)

        sourceIP_label = tk.Label(self.guiframe,text="Inside IP:")
        sourceIP_label.place(relx=0.145,rely=0.15,anchor="ne")

        destinationIP_label = tk.Label(self.guiframe,text="Outside IP:")
        destinationIP_label.place(relx=0.145,rely=0.2,anchor="ne")

        insideInterface_label = tk.Label(self.guiframe,text="Inside Interface:")
        insideInterface_label.place(relx=0.145,rely=0.25,anchor="ne")

        outsideInterface_label = tk.Label(self.guiframe,text="Outside Interface:")
        outsideInterface_label.place(relx=0.145,rely=0.3,anchor="ne")
        
        self.connection_label = tk.Label(self.guiframe,text="Not Connected")
        self.connection_label.place(relx=0.02,rely=0.88,anchor="nw")																			 
																	 
		
        #ENTRY BOXES

        self.csv_entry = tk.Entry(self.guiframe,width=27)
        self.csv_entry.insert(0,"Insert/choose path")
        self.csv_entry.place(relx=0.12,rely=0.053)

        self.sourceIP_entry = tk.Entry(self.guiframe)
        self.sourceIP_entry.place(relx=0.17,rely=0.153)

        self.destinationIP_entry = tk.Entry(self.guiframe)
        self.destinationIP_entry.place(relx=0.17,rely=0.2)

        self.insideInterface_entry = tk.Entry(self.guiframe)
        self.insideInterface_entry.insert(0,"inside")
        self.insideInterface_entry.place(relx=0.17,rely=0.252)

        self.outsideInterface_entry = tk.Entry(self.guiframe)
        self.outsideInterface_entry.insert(0,"outside")
        self.outsideInterface_entry.place(relx=0.17,rely=0.301)

        #self.mainframe.place(relx=0,rely=0,width=800,height=850)

        #BUTTONS

        csv_import = tk.Button(self.guiframe,text="import CSV",command= lambda: self.csv_method_input())
        csv_import.place(relx=0.45,rely=0.35)

        choose_csv = tk.Button(self.guiframe,text="...",command= lambda: self.csv_choose())
        choose_csv.place(relx=0.33,rely=0.053)

        manual_add_nat = tk.Button(self.guiframe,text="Add NAT",command= lambda: self.manual_method_input())
        manual_add_nat.place(relx=0.37,rely=0.35)

        clear_treeview = tk.Button(self.guiframe,text="Clear",command= lambda: self.treeview_clear())
        clear_treeview.place(relx=0.64,rely=0.35)

        build_nat = tk.Button(self.guiframe,text="Build NATs",command=lambda: self.natrule_build())
        build_nat.place(relx=0.545,rely=0.35)

        Firewall_check_ips = tk.Button(self.guiframe,text="Check IPs", command= lambda: self.login_check())
        Firewall_check_ips.place(relx=0.695,rely=0.35)

        nat_help_btn = tk.Button(self.guiframe,text="Help",command= lambda : nat_help.helppage())
        nat_help_btn.place(relx=0.78,rely=0.35)

        self.deploy_nat_btn = tk.Button(self.guiframe,text="Deploy Rules",command = lambda : Firewall_Check.nat_deploy())
        self.deploy_nat_btn.config(state="disabled")
        self.deploy_nat_btn.place(relx=0.5,rely=0.9,anchor="n")
        
        firewall_discnt_btn = tk.Button(self.guiframe,text="Disconnect",font=("",8),command = lambda : Firewall_Check.close_connection())
        firewall_discnt_btn.place(relx=0.02,rely=0.91,anchor="nw")																															  									  
        
        #TEXTBOX

        self.natconfig_text = tk.Text(self.guiframe,width=94, height=25,state="disabled")
        self.natconfig_text.place(relx=0.02,rely=0.4)

        #TREEVIEW

        cols = ("Inside Int","Inside IP","Outside Int","Outside IP")

        self.nat_treeview = ttk.Treeview(self.guiframe,columns=cols,show="headings",height=11)

        for col in cols: #setting text in column headers and the width of each column
            self.nat_treeview.heading(col, text=col) #header
            self.nat_treeview.column(col,minwidth=0,width=118) #width

        self.nat_treeview.place(relx=0.37,rely=0.05)

        #SCROLLBARS

        self.nat_treeview_scrlbar = ttk.Scrollbar(self.guiframe, orient="vertical", command=self.nat_treeview.yview)
        self.nat_treeview_scrlbar.place(relx=0.965,rely=0.05,height=248) #placing scrollbar next to table
        self.nat_treeview.configure(yscrollcommand=self.nat_treeview_scrlbar.set) #mapping scrollbar so it will move the table on the y axis

        self.guiframe.place(x=0, y=35, relwidth=1, relheight=1)


    def csv_choose(self):#allowing selecting of CSV from file explorer_

        root.update()
        self.csv_location = filedialog.askopenfilename(initialdir="/", title="select a file",filetypes=(("csv files","*.csv"),("all files","*.*")))
        self.csv_entry.delete(0, 'end')
        self.csv_entry.insert(1,self.csv_location)

    def csv_method_input(self):
        self.csv_entry = self.csv_entry.get()
        #self.nat_treeview = nat_treeview
        self.deploy_nat_btn.config(state="disabled")

        #if the user copies CSV as path it will start and trail with "" which causes issue as python adds '', this is finding the "" and removing it
        self.csv_entry = self.csv_entry.replace('"',"")

        #Defining a empty string to add to during for loop
        Public_IP = "" 
        Private_IP = ""
        Inside_Interface = ""

        try:

            #opening the CSV, adding to a variable caled data and then for each row it is add the private and public IPs to the variable
            with open(self.csv_entry) as c:
                data = csv.reader(c)
                for row in data:
                    Private_IP+=","+row[12]
                    Public_IP+=","+row[17]
                    Inside_Interface+=","+row[10]

            #replacing the title of row and additinal commas with nothing
            Public_IP = Public_IP.replace(",PublicIPAddress,","")
            Private_IP = Private_IP.replace(",IPAddress,","")
            Inside_Interface = Inside_Interface.replace(",FirewallNameIF,","")

            Public_IP = Public_IP.replace(" ","")
            Private_IP = Private_IP.replace(" ","")
            Inside_Interface = Inside_Interface.replace(" ","")

            Public_IP = Public_IP.split(",")
            Private_IP = Private_IP.split(",")
            Inside_Interface = Inside_Interface.split(",")

            #for loop to add values from CSV into treeview
            for (x,y,z) in zip(Public_IP,Private_IP,Inside_Interface): #Zipping all lists into tuple so it add correctly
                #Test to make sure IPs are valid
                if self.validation(x) == False or self.validation(y) == False :
                    self.treeview_clear() #clears the treeview table is error as it is could have added correct IPs before getting to invalid ones
                    messagebox.showerror(title="Error",message="IP not valid!")
                    break

                elif ipaddress.ip_address(x).is_private == True: #Check to make sure IP is public
                    self.treeview_clear() #clears the treeview table is error as it is could have added correct IPs before getting to invalid ones
                    messagebox.showerror(title="Error",message="An Priavte IP have been entered in the Public IP column!")

                elif ipaddress.ip_address(y).is_private == False: #check to make sure IP is private
                    self.treeview_clear() #clears the treeview table is error as it is could have added correct IPs before getting to invalid ones
                    messagebox.showerror(title="Error",message="An Public IP have been entered in the Private IP column!")
                
                else:
                    self.nat_treeview.insert("","end",values=(z,y,"outside",x))
        
        except FileNotFoundError:
            messagebox.showerror(title="Error",message="File not Found!") #handles error is invalid IP is entered
    
    def treeview_clear(self): #Method to clear treeview table

        x = self.nat_treeview.get_children()
        for i in x:
            self.nat_treeview.delete(i)

    def manual_method_input(self):#method to input IPs/interfaces entered into treeview
        
        #getting all of entries
        self.sourceIP = self.sourceIP_entry.get()
        self.destinationIP = self.destinationIP_entry.get()
        self.insideInterface = self.insideInterface_entry.get()
        self.outsideInterface = self.outsideInterface_entry.get()

        self.deploy_nat_btn.config(state="disabled") #when button click it is setting state of deploy nat button to disabled until user runs checks again

        ### CODE ALLOWING RANGES TO BE ADDED ###

        try: #used to try and process the IPs as if a range is entered, if a range is not entered it will catch the error and process as single ip 

            valid_ip = True #Variable used to decided if entered IPs are valid

            ##Allows the user to add a range of private IPs
            priv_ip_range = (self.sourceIP.split("-"))# getting and spliting the range inputted by the user 
            priv_start_ip = priv_ip_range[0]
            priv_end_ip = priv_ip_range[1]

            if self.validation(priv_start_ip) == False or self.validation(priv_end_ip) == False: #checking if IPs for start and end of range are valid
                valid_ip = False
                messagebox.showerror(title="Error",message="IP in Private range not valid!") 

            elif ipaddress.ip_address(priv_start_ip).is_private == False or ipaddress.ip_address(priv_end_ip).is_private == False: #checking if IPs for start/end of range are private
                valid_ip = False
                messagebox.showerror(title="Error",message="A public Address has been entered into the inside IP box!")

            else: #if valid it is creating the range
                priv_start_ip = priv_start_ip.split(".") #spliting the IPs into indivdual octects
                priv_end_ip = priv_end_ip.split(".")

                priv_startoct = int(priv_start_ip[3]) #getting the last octect of each IP
                priv_endoct = int(priv_end_ip[3])
                priv_ips = []

                for x in range(priv_startoct,priv_endoct+1): #working out the range of the octects
                    ip = priv_start_ip[0:3]
                    ip.append(str(x))
                    priv_ips.append(".".join(ip))

            ##Allows the user to add a range of Public IPs
            pub_ip_range = (self.destinationIP.split("-"))# getting and spliting the range inputted by the user 
            pub_start_ip = pub_ip_range[0]
            pub_end_ip = pub_ip_range[1]

            if self.validation(pub_start_ip) == False or self.validation(pub_end_ip) == False: #checking if IPs for start and end of range are valid
                valid_ip = False
                messagebox.showerror(title="Error",message="IP in Public range not valid!") 

            elif ipaddress.ip_address(pub_start_ip).is_private == True or ipaddress.ip_address(pub_end_ip).is_private == True:#checking if IPs for start/end of range are Public
                valid_ip = False
                messagebox.showerror(title="Error",message="A Private Address has been entered into the Outside IP box!")

            else: #if valid it is creating the range
                pub_start_ip = pub_start_ip.split(".") #spliting the IPs into indivdual octects
                pub_end_ip = pub_end_ip.split(".")

                pub_startoct = int(pub_start_ip[3]) #getting the last octect of each IP
                pub_endoct = int(pub_end_ip[3])
                pub_ips = []

                for x in range(pub_startoct,pub_endoct+1): #working out the range of the octects
                    ip = pub_start_ip[0:3]
                    ip.append(str(x))
                    pub_ips.append(".".join(ip))

            if valid_ip == True: #If they IPs are valid and pass the test it will carry on deploying

                if len(priv_ips) == len(pub_ips): #checking the number of public and private match


                    for priv,pub in zip(priv_ips,pub_ips):  #putting into treeview
                            self.nat_treeview.insert("","end",values=(self.insideInterface,priv,self.outsideInterface,pub))
                else:
                    messagebox.showerror(title="Error",message="Ranges not equal length!") 

        except IndexError: #If it catches a index Error it means a range has not been inputted   
        
            #if function to check IPs are valid, if not will display a messagebox and not add NAT to treeview table
            if  self.validation(self.sourceIP) == False:
                messagebox.showerror(title="Error",message="Private IP not valid!")
            elif self.validation(self.destinationIP) == False:
                messagebox.showerror(title="Error",message="Public IP not valid!")
                
            elif ipaddress.ip_address(self.sourceIP).is_private == False:
                messagebox.showerror(title="Error",message="Public IP entered in Private IP!")
            elif ipaddress.ip_address(self.destinationIP).is_private == True:
                messagebox.showerror(title="Error",message="Private IP entered in Public IP!")
            else:
                #inserting into treeview
                self.nat_treeview.insert("","end",values=(self.insideInterface,self.sourceIP,self.outsideInterface,self.destinationIP))

    def natrule_build(self):

        self.natconfig_text.config(state="normal") #making sure state is normal so output can be added
        self.natconfig_text.delete("1.0","end")

        #for loop to get each line of values and put them into config and print to the screen
        x = self.nat_treeview.get_children()
        for i in x:
            data = (self.nat_treeview.item(i)["values"]) #getting a line of values 
            inside_int = data[0]
            inside_ip = data[1]
            outside_int = data[2]
            outside_ip = data[3]

            outside_ip_name = outside_ip.replace(".","-") #replacing IP dots with - to be used for the object name
            self.natconfig_text.insert("end",f"object network {outside_ip_name}_outside \n host {outside_ip}") #printing name created on line above and the actual IP intented under it

            inside_ip_name = inside_ip.replace(".","-") #replacing IP dots with _ to be used for the object name
            self.natconfig_text.insert("end",f"\nobject network {inside_ip_name}_inside \n host {inside_ip}") #printing name created on line above and the actual IP intented under it
            self.natconfig_text.insert("end",f"\n nat ({inside_int},{outside_int}) static {outside_ip_name}_outside \n\n") #printing the actual NAT rule
        
        self.natconfig_text.config(state="disabled") #chaging state back to disabled so errors can't be made by accidental typing

    def login_check(self): #method to check if the user is already connected to a firewall 

        if Firewall_Check.connection_check() == True:
            Firewall_Check.ip_checks()
            
        else:
            self.connection_label.config(text="Not Connected")
            Firewall_Check.PopOut()
            

class PageController(GUIPage, ACLGUIPage):
    
    def __init__(self):
        GUIPage.__init__(self)
        ACLGUIPage.__init__(self)
 
        self.r = tk.IntVar() #defining tkinter varaible
        self.r.set(1) #setting it to default to the NAT Builder Page 
        self.switch_page() #Running the function so it loads the page

        #The two radio Buttons
        NAT_Radio = tk.Radiobutton(root,text="NAT Builder",indicator=1,variable=self.r,value=1,command= lambda: self.switch_page())
        NAT_Radio.place(relx=0.495,rely=0.01,anchor="ne")
        
        ACL_Radio = tk.Radiobutton(root,text="ACL Builder",indicator=1,variable=self.r,value=2, command= lambda: self.switch_page())
        ACL_Radio.place(relx=0.505,rely=0.01,anchor="nw")
    
    def switch_page(self): #Function 

        page = self.r.get()
        if page == 1:
            self.guiframe.lift()
        elif page == 2:
            self.ACLFrame.lift()


class IPFirewallCheck(GUIPage): #Class to allow users to check IPs entered on Firewall
    
    def __init__(self):
        GUIPage.__init__(self)
			 

    def PopOut(self):

        self.root = tk.Toplevel()
        self.root.grab_set() #means user cannot touch mainwindow while entering creds

        #POPOUT LABELS

        firewallIP_label = tk.Label(self.root,text="Firewall IP:")
        firewallIP_label.place(relx=0.2,rely=0.1)

        username_label = tk.Label(self.root,text="Username:")
        username_label.place(relx=0.2,rely=0.25)

        password_label = tk.Label(self.root,text="Password:")
        password_label.place(relx=0.2,rely=0.4)

        enable_label = tk.Label(self.root,text="enable:")
        enable_label.place(relx=0.2,rely=0.55)

        #POPOUT ENTRYBOXES
        self.firewallIP_entry = tk.Entry(self.root)
        self.firewallIP_entry.place(relx=0.45,rely=0.1)

        self.username_entry = tk.Entry(self.root)
        self.username_entry.place(relx=0.45,rely=0.25)

        self.password_entry = tk.Entry(self.root,show="*")
        self.password_entry.place(relx=0.45,rely=0.4)

        self.enable_entry = tk.Entry(self.root,show="*")
        self.enable_entry.place(relx=0.45,rely=0.55)

        #POPOUT BUTTONS
        confirm_button = tk.Button(self.root,text="OK",command= lambda : self.firewall_connection())
        confirm_button.place(relx=0.4,rely=0.8)

        cancel_button = tk.Button(self.root,text="Cancel",command= self.root.destroy)
        cancel_button.place(relx=0.5,rely=0.8)

        self.root.title("Credential Input")
        self.root.geometry("300x220")
        self.root.mainloop()

    def firewall_connection(self): #Method for connecting to the firewalls called when users hits check IPs button

        self.firewallIP = self.firewallIP_entry.get()
        username = self.username_entry.get()
        password = self.password_entry.get()
        enable = self.enable_entry.get()

        try:
            cisco = {
                'device_type': 'cisco_asa',
                'host': self.firewallIP,
                'username': username,
                'password': password,
                'secret' : enable,
                'fast_cli': True,
                }
                
        
            self.net_connect = ConnectHandler(**cisco)
            self.net_connect.enable()
            #print("connection made")
            self.connection_label.config(text=f"Connected: {self.firewallIP}")
        
            #print(self.connection_label.cget("text"))
            #print("beforechecks")
            self.ip_checks()

        except netmiko.ssh_exception.AuthenticationException as error:
            print(type(error))
            messagebox.showerror(title="Error",message="Authentication failed!")

        except ValueError:
            messagebox.showerror(title="Error",message="Please Enter an Firewall IP!")

    def ip_checks(self): #Function for When "OK" button is clicked
        
        #print("checking IPs")
        
        if self.validation(self.firewallIP) == False:
            messagebox.showerror(title="Error!",message="Firewall IP Not Valid!")
        else:
            self.root.destroy()
            #print("followed else path")
            
            try:
                
                x = self.nat_treeview.get_children() #Getting all the values in the treeview (interfaces, IPs)
                #print(isinstance(self.nat_treeview,GUIPage))
                #print(x)

                #print("got treeview")
                
                self.natconfig_text.config(state="normal") #making sure state is normal so output can be added
                self.natconfig_text.delete("1.0","end")

                #print("config of textbox")
                
                for i in x:

                    data = (self.nat_treeview.item(i)["values"]) #getting a line of values 
                    self.inside_ip = data[1] #getting inside IP in column 1
                    self.outside_ip = data[3] #getting outside IP in column 3
                    #print(data)
                    
                    #running checks for inside IPs
                    run_check = self.net_connect.send_command_expect(f"show run | include {self.inside_ip}",delay_factor=2,max_loops=500)
                    nat_check = self.net_connect.send_command_expect(f"show nat | include {self.inside_ip}",delay_factor=2,max_loops=500)
                    xlate_check = self.net_connect.send_command_expect(f"show run | include {self.inside_ip}",delay_factor=2,max_loops=500)
                    arp_check = self.net_connect.send_command_expect(f"show arp | include {self.inside_ip}",delay_factor=2,max_loops=500)
                    ping_check = self.net_connect.send_command_expect(f"ping {self.inside_ip} repeat 3 timeout 1",delay_factor=2,max_loops=500)
                    
                    #if no result is returned it will change it to no results to make it easier
                    if run_check == "":
                        run_check = "No results\n"

                    if nat_check == "":
                        nat_check = "No results\n"

                    if xlate_check == "":
                        xlate_check = "No results\n"

                    if arp_check == "":
                        arp_check = "No results\n"
                    
                    print("inside checks done")

                    #printing results to GUI
                    self.natconfig_text.insert("end",f"Checks for IP: {self.inside_ip}\n\n")
                    self.natconfig_text.insert("end",f"Show Run:\n{run_check}\nShow Nat:\n{nat_check}\nShow Xlate:\n{xlate_check}\nShow ARP:\n{arp_check}\nPing:\n{ping_check}\n\n")
                    self.natconfig_text.insert("end","--------------------------------------------\n")

                    #running checks for outside IPs
                    run_check = self.net_connect.send_command_expect(f"show run | include {self.outside_ip}",delay_factor=2,max_loops=500)
                    nat_check = self.net_connect.send_command_expect(f"show nat | include {self.outside_ip}",delay_factor=2,max_loops=500)
                    xlate_check = self.net_connect.send_command_expect(f"show run | include {self.outside_ip}",delay_factor=2,max_loops=500)
                    arp_check = self.net_connect.send_command_expect(f"show arp | include {self.outside_ip}",delay_factor=2,max_loops=500)

                    #if no results are found it will change the blank to no results
                    if run_check == "":
                        run_check = "No results\n"

                    if nat_check == "":
                        nat_check = "No results\n"

                    if xlate_check == "":
                        xlate_check = "No results\n"

                    if arp_check == "":
                        arp_check = "No results\n"

                    print("outside checks done")
                    
                    #printing to GUI
                    self.natconfig_text.insert("end",f"Checks for IP: {self.outside_ip}\n\n")
                    self.natconfig_text.insert("end",f"Show Run:\n{run_check}\nShow Nat:\n{nat_check}\nShow Xlate:\n{xlate_check}\nShow ARP:\n{arp_check}\n\n")
                    self.natconfig_text.insert("end","--------------------------------------------\n")

                self.natconfig_text.config(state="disabled") #chaging state back to disabled so errors can't be made by accidental typing
                self.deploy_nat_btn.config(state="normal") #letting deploy button be clicked as checks have been run

            except Exception as error:
                print(error)
                messagebox.showerror(title="Error",message=f"An Error Has Occured!\n\nError Type:{type(error)}")

    def nat_deploy(self):
        
        try:

            config = self.natconfig_text.get(1.0,"end") # getting the config from the text box

            if config[0:14] != "object network": #if statement to check the user has run the build NAT button
                messagebox.showerror(title="Error",message=f"Please build the NAT config!")

            else: #assuming the user has built the config with the 'Build NAT' Button it will apply to the firewall
                
                output = self.net_connect.send_config_set(config,exit_config_mode=True)

                self.natconfig_text.config(state="normal")
                self.natconfig_text.delete(1.0,"end")
                self.natconfig_text.insert("end",f"The following NATs have been created on the Firewall:\n\n")

                x = self.nat_treeview.get_children()

                for i in x:
                    data = (self.nat_treeview.item(i)["values"]) #getting a line of values 
                    check_created_ip = data[1] #getting inside IP in column 1

                    nat_output = self.net_connect.send_command(f"show nat | include {check_created_ip}",delay_factor=0)

                    if nat_output == "":
                        self.natconfig_text.delete(1.0,"end")
                        self.natconfig_text.insert("end",f"There looks to have been an error:\n\n{output}")
                        break

                    else:
                        self.natconfig_text.insert("end",f"{nat_output}\n")
 
                self.natconfig_text.config(state="disabled")

        except AttributeError:
            messagebox.showerror(title="Error",message=f"Please run checks first!")
        except OSError:
            messagebox.showerror(title="Error",message=f"No NAT config to apply!")
        except Exception as error:
            print(type(error))
            messagebox.showerror(title="Error",message=f"An Error Has Occured!\n\nError Type:{type(error)}")

    def connection_check(self): #Method to check if the firewall is still connected to stop the user signing in lots of times

        try:
            prompt = self.net_connect.find_prompt() #Will attempted to get prompt
            
            if prompt != "": #if prompt not empty it will return True
                return True

            elif prompt == "": #if prompt empty meaning no connection it will return false
                return False

        except AttributeError: #returning false if attribute error meaning not connection has been made yet
            return False
        except OSError:
            return False

    def close_connection(self): #Method to close the connection to the firewall

        try:
            self.net_connect.disconnect()
            self.connection_label.config(text="Not Connected")
        except AttributeError:
            pass																															 


def ip_validation(IPs):#function to validate IPs

        a = IPs.split(".") #Spliting each Octet of the IP
        if len(a) %4 != 0: #checking that there are 4 Octents otherwise is not valid
            return False
        for x in a: 
            if x.isdigit() == False: #checking if each octet is a number or not
                return False
            i = int(x) #changing octent to integer type
            if i < 0 or i > 255: #then checking if each octet is between 0 and 255
                return False

root = tk.Tk()
root.title("NAT Builder v2.9")
root.geometry("800x850")
aclpage = ACLGUIPage()
natpage = GUIPage()
pagecntrl = PageController()
Firewall_Check = IPFirewallCheck()								  
root.mainloop()