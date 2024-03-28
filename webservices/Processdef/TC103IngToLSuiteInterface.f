#<HEADER>
#<COPYRIGHT>
#© 2008 INSURANCE SOFTWARE SOLUTIONS CORP.  ALL RIGHTS RESERVED
#</COPYRIGHT>
#</HEADER>
# *****************************************************************************
# Mandat Date      Auth. Description
# IN003  17Jan2008 JFO   New Process Flow to build the TC103 XML transaction in 
#                        order to send it into LifeSuite.
#                        Revised on November 2011.
#        06Dec2011 JFO   Faire des validations sur certaines info de l'assuré
#                        concernant le MIB.
# J03034 15Feb2013 JFO   Ne plus transférer la valeur "MIR-AGT-TEAM-ASIGN-CD" vers LS.
# J03598 13Jan2014 JFO   Lire le P-STEP BF0684-P au lieu de BF0680-P afin de charger
#                        tout le contenu de la sous-table d'EDIT "BRCHLS" dans un 
#                        tableau virtuel. Maximum 200 occurs par lecture. REF: BLFS-106
# j03607 21Jan2014 JFO   Changement de validation pour les couvertures liées
# J03692 07Mar2014 JFO   If the contract is designated as VIP change the priority to "1" in LifeSuite.
# BLFS-127 31Aapr2014 JFO ajouté deux nouvelles garanties complémentaires dans LifeSuite. "68" et "69".
#                        et faire transférer le capital nominal de ces deux G.C vers LS.
# J03819 22aou2014 MTH   Ajouter une validation pour la proposition electronique (validation identique a celle du CSDI5990) 
# J03998 18Sep2014 JFO   Ajouter le type COI 'U' pour l'ajout d'une G.C MG/GA.
# J04226 06Mar2015 JFO   Prendre l'age de l'assuré en provenance du P-STEP BF8022-P.p plutôt que de faire la calcul année - année
# J04290 19Jun2015 JFO   Alimenter le champ CvgCovNum-T de l'assuré 1 CVG 01 pour le benefit enfant à naître.
# BLFS-201 11Mar2016 JFO Nouvel algorithme afin de préciser le niveau de priorité du contrat pour la tarification dans LS.
#						 Aussi mettre la priorité 2 pour une prime de 15 000,00 et+ et priorité 1 pour le capital nominal 
#						 de 500 000,00 et+ pour AXACI et 55 000 000,00 et+ pour AXALIFE et PREF.
# I125348 23MAR2017 JFO  Avant le rappel du AppBF8002-P pour mettre à jour la date de transfert LifeSuite sur la police,
#                        Il faut réinitialiser les valeurs des variables MIR... de TPOL en rappelant le BF8000-P afin de ne pas
#                        écraser ou modifier des valeurs sur la police par des valeurs qui peuvent être modifiés
#                        durant le traitement de transformation du contrat pour le format LifeSuite.
# Lifesuite9 18MAR2017 MTH Rehaussement LifeSuite version 9 
# CLIEDIS    08DEC2017 JFO Déclencher la transaction EAPP pour CLIEDIS.
# J06082 26Jul2019 JFO   Création de la FDT NS98 lorsque le transfert Life Suite échoue via eAPP.
# J06116 01OCT2019 GCL   Changement parce que le code AXALIFEPREF doit apparaître seulement pour au moins 500k$ de Face Amt.
# *********************************************************************************************************************************
PROCESS TC103IngToLSuiteInterface
{
	VARIABLES
	{
		# This input variables contains a policy number.
		IN MIR-POL-ID-BASE;
		IN MIR-POL-ID-SFX;
		# This output variable contains informations to be send at screen at the end of process.
		OUT MIR-DV-LS-INTRFCE-RSPSE;
		OUT MIR-DV-LS-TRGR-MSG-T[25];
		OUT MIR-POL-CSTAT-CD;
		OUT MIR-PLAN-ID;
		OUT MIR-POL-CVG-REC-CTR;
		OUT MIR-POL-APP-SIGN-DT;
		OUT MIR-POL-APP-SIGN-IND;
		OUT MIR-POL-MIB-SIGN-CD;
	}
	#------------------------------------- Constante variables -----------------------------

	WS-POL-ID = UPPER(MIR-POL-ID-BASE) + UPPER(MIR-POL-ID-SFX);
	WsHypotoitDurAmt15 = 9135;
	WsHypotoitDurAmt20 = 10116;
	WsHypotoitDurAmt25 = 10699;
	WsMaxiRevnuDurAmt15 = 130;
	WsMaxiRevnuDurAmt20 = 155;
	WsMaxiRevnuDurAmt25 = 180;
	MIR-DV-EFF-DT = SESSION.LSIR-PRCES-DT;
	time = SESSION.LSIR-SYS-TIME;
	formatted-time = SUBSTRING(time, 1, 2) + ":" + SUBSTRING(time, 3, 2) + ":" + SUBSTRING(time, 5, 2);

	#---------------------------------- Working storage variables ------------------------------
	WS-DV-TRGR-SW = "ON";
	WS-FRST-CVG = 0;
	INDX = 1;
	KeyIdx = 0;
	CBindex = 0;
	WS-IndDisabilityPlan = "N";
	FirstCvgPrcesDone = "N";
	GreaterCvgFaceAmt = 0;
	OwnerIsInsuredID = "";
	SecondOwnerIsInsuredID = "";
	OwnerId = "";
	SecondOwnerId = "";
	WS-SERV-AGT-ID = "";
	MsgsIdx = 1;
	WS-PARTY-ERROR = "1";
	WS-CVG-ERROR = "0";
	WS-LS-CALLBACK-ERROR = "N";
	#
	#******************* Build heading and Authentification of TC103 XML ***********************
	#
#	IF SESSION.MIR-USER-ID != "FONTAIJA"
#	{
#		EXIT;
#		MIR-DV-LS-TRGR-MSG-T[1] = "Votre USERID " + "(" + SESSION.MIR-USER-ID + ") " + "ne permet pas le transfert vers LifeSuite";
#		BRANCH OutputData;
#	}
	TXLife.UserAuthRequest.UserLoginName = SESSION.MIR-USER-ID;
#	TXLife.UserAuthRequest.UserLoginName = "fontaj02";
	TXLife.UserAuthRequest.UserPswd.CryptType = "NONE";
#	TXLife.UserAuthRequest.UserPswd.Pswd = "*******";
	TXLife.UserAuthRequest.UserDate = SESSION.LSIR-SYS-DT-EXT;
	TXLife.UserAuthRequest.UserTime = formatted-time;

	TXLifeRequest.TransRefGUID = UID();

	TXLifeRequest.TransType.tc = toTXLife("NewBusinessSubmission", "TransType");
	TXLifeRequest.TransType.Value = GetDescription("NewBusinessSubmission", "TransType");
	# *********************************************************
	# Create all based information
	#	- Policy number
	#	- Number of the proposal
	#	- Language of correspondence
	#	- Received date
	#	- Assigned team
	# *********************************************************

	#*******************************
	# Collect Based Contract Detail
	#******************************* 
	STEP ContractRetrieve
	{
		USES P-STEP "BF8000-P";
		ATTRIBUTES
		{
			GetMessages = "Merge";
		}
	}
	IF LSIR-RETURN-CD != "00" 
	{
		# The policy retrieve doesn't work successfully. So turn off the trigger's switch.
		WS-DV-TRGR-SW = "OFF";
	}
	# If the trigger's switch is turned OFF, so stop process and send error message at screen.
	IF WS-DV-TRGR-SW == "OFF"
	{
		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
		{
			MsgsIdx = MsgsIdx + 1;
		}
		# LifeSuite's transfer could not be triggered because error on the contract.   
		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600003";
		BRANCH WriteUserMessage;
	}
	# CLEIDIS - 08DEC2017 - JFO
	# Déclanchement de la transaction CLIEDIS EAPP - Appel du P-STEP "BF9402-P"
	STEP Trigger_EAPP_CLEIDIS
	{
		USES P-STEP "BF9402-P";
		ATTRIBUTES
		{
			GetMessages = "No";
		}
		WS-POL-ID -> MIR-POL-ID-BASE;
	}
	
	
	#Check all application signatures. if one of those there are not yet received so turn OFF the trigger's switch and send message at screen.
	IF MIR-POL-MIB-SIGN-CD != "Y" || MIR-POL-APP-SIGN-IND != "Y" || MIR-POL-APP-SIGN-DT == "" 
	{
		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
		{
			MsgsIdx = MsgsIdx + 1;
		}
		# The required application signatures have not been received. The transfer to LifeSuite cannot be processed.  
		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600004";
		WS-DV-TRGR-SW = "OFF";
	}
# Début J03819
        IF (SUBSTRING(MIR-POL-APP-FORM-ID, 1, 1) ==  "E" && MIR-POL-ELEC-PRPS-IND != "Y") 
        {
                WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
                {
                         MsgsIdx = MsgsIdx + 1;
                }
                # Electonic application must be selected if application number start with a "E". 
                MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92609001";
                WS-DV-TRGR-SW = "OFF";
        }
        IF (SUBSTRING(MIR-POL-APP-FORM-ID, 1, 1) !=  "E" && MIR-POL-ELEC-PRPS-IND == "Y") 
        {
                WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
                {
                         MsgsIdx = MsgsIdx + 1;
                }
                # If Electonic proposal is selected, the application form ID number must start by 'E'.
                MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92609002";
                WS-DV-TRGR-SW = "OFF";
        }
# Fin J03819
#	IF MIR-POL-CSTAT-CD != "PCRC"
#	{
#		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
#		{
#			MsgsIdx = MsgsIdx + 1;
#		}
#		#The LifeSuite's transfer could not be triggered because error on the contract.   
#		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600003";
#		WS-DV-TRGR-SW = "OFF";
#		BRANCH WriteUserMessage;
#	}
	# Check if the contract is not already transferred. So turn OFF the trigger's switch and send message at screen.
	IF MIR-POL-PREV-TRNFR-LS-DT != ""
	{
		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
		{
			MsgsIdx = MsgsIdx + 1;
		}
		#This contract was already transferred to LifeSuite. A new transfer is not possible for the moment.          
		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600005";
		MIR-MSG-PARM-INFO-1-T[MsgsIdx] = MIR-POL-PREV-TRNFR-LS-DT;
		WS-DV-TRGR-SW = "OFF";
	}
	#Check for the servicing agent. If Inactive turn OFF the trigger's Switch and send message at screen.
	IF MIR-SERV-AGT-ID == ""
	{
#J03034 - Begin - Si l'agent de service est à blanc sur la table police ne pas transférer. 
#		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
#		{
#			MsgsIdx = MsgsIdx + 1;
#		}
#		MIR-SERV-AGT-ID = MIR-AGT-ID-T[1];
#		WS-SERV-AGT-ID = MIR-AGT-ID-T[1];
#		STEP GetAgentInfo1
#		{
#			USES P-STEP "BF1420-P";
#			MIR-SERV-AGT-ID -> MIR-AGT-ID;
#		}
#		IF MIR-AGT-STAT-CD == "I"
#		{
			#The servicing agent is blank on policy and the writing agent is inactive. The policy cannot be transfered.
			MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600014";
			WS-DV-TRGR-SW = "OFF";
#		}
#		ELSE
#		{
#			#Attention- The servicing agent is blank on policy. The writing agent number has been taken by default. 
#			MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600013";
#		}
#J03034 End.
	}
#	BRANCH TARGET0210;
	# *****************************************************************
	# Perform Policy and Coverage Analysis.  Each coverage status
	# should change to Complete.  Then, update policy once more.
	# Finally, display Application Summary data and give the ability
	# to cross edit and clear case u/w.  Messages from Policy Update
	# and Check for Errors steps will be merged and displayed.
	# *****************************************************************
	STEP PolicyCoverageAnalysis
	{
		USES P-STEP "BF8004-P";
		ATTRIBUTES
		{
			GetMessages = "Yes";
		}
		"Y" -> MIR-BYPASS-MSGS-IND;
	}
	# Check Coverages status. If one coverage is not setted to Complete, turn OFF trigger's switch and send message at screen. 
	I = 1;
	WHILE I <= NUMBER(MIR-POL-CVG-REC-CTR)
	{
		IF MIR-CVG-CSTAT-CD-T[I] != "PCC"
		{
			WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
			{
				MsgsIdx = MsgsIdx + 1;
			}
			#LifeSuite's transfer could not be triggered because of an error on coverage ( @1 ).   
			MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600011";
			IF I < 10
			{
				MIR-MSG-PARM-INFO-1-T[MsgsIdx] = "0" + I;
			}
			ELSE
			{
				MIR-MSG-PARM-INFO-1-T[MsgsIdx] = I;
			}
			WS-DV-TRGR-SW = "OFF";
		}
		I = I + 1;
	}
	TARGET0210:
	# Check if one error has been detected in the contract.
#J03034 Begin ne pas afficher le message XS9260 0001
#	IF WS-DV-TRGR-SW == "ON"
	IF WS-DV-TRGR-SW == "OFF"
#	{
#		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
#		{
#			MsgsIdx = MsgsIdx + 1;
#		}
#		# No errors were detected on the policy. LifeSuite's transfer has been triggered successfully.  
#		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600001";
#	}
#	ELSE
#J03034 End
	{
		BRANCH WriteUserMessage;
	}
	#If all requirements and all coverages are OK but an error on the policy so force the policy's status to PCRC and process tranfer. 
	IF MIR-POL-CSTAT-CD != "PCRC"
	{
		MIR-POL-CSTAT-CD = "PCRC";
	}
	# .
	# .
	# .         ...................    build "OLifE.SourceInfo" tags    ............
	# .
	# .
	TXLifeRequest.OLifE.SourceInfo.CreationDate = SESSION.LSIR-SYS-DT-EXT;
	TXLifeRequest.OLifE.SourceInfo.CreationTime = formatted-time;
	TXLifeRequest.OLifE.SourceInfo.SourceInfoName = "LifeSuite";
	# .
	# .
	# .         ...................    build "OLifE.Holding" tags    ............
	# .
	# .	
	TXLifeRequest.OLifE.Holding[1].id = "Holding_" + INDX;
	TXLifeRequest.OLifE.Holding[1].HoldingName = "Policy";
	TXLifeRequest.OLifE.Holding[1].HoldingStatus.tc = toTXLife(MIR-POL-CSTAT-CD, "HoldingStatus"); 
	TXLifeRequest.OLifE.Holding[1].HoldingStatus.Value = GetDescription(MIR-POL-CSTAT-CD, "HoldingStatus");
	TXLifeRequest.OLifE.Holding[1].HoldingTypeCode.tc = "2";
	TXLifeRequest.OLifE.Holding[1].HoldingTypeCode.Value = GetDescription("2", "HoldingTypeCode");
	TXLifeRequest.OLifE.Holding[1].Purpose.tc = toTXLife(MIR-POL-INS-PURP-CD, "Purpose");
	TXLifeRequest.OLifE.Holding[1].Purpose.Value = GetDescription(MIR-POL-INS-PURP-CD, "Purpose");
	# .
	# .
	# .         ...................    build "OLifE.Holding.Policy" tags    ............
	# .
	# .	
	TXLifeRequest.OLifE.Holding[1].Policy.StatusReason.tc = "2147483647";
	TXLifeRequest.OLifE.Holding[1].Policy.StatusReason.Value = GetDescription("2147483647", "StatusReason");
	TXLifeRequest.OLifE.Holding[1].Policy.CarrierCode = "SSQ";
	TXLifeRequest.OLifE.Holding[1].Policy.PolNumber = UPPER(MIR-POL-ID-BASE) + UPPER(MIR-POL-ID-SFX);
	TXLifeRequest.OLifE.Holding[1].Policy.Jurisdiction.tc = toTXLife(MIR-POL-ISS-LOC-CD, "StateTC");
	TXLifeRequest.OLifE.Holding[1].Policy.Jurisdiction.Value = GetDescription(MIR-POL-ISS-LOC-CD, "StateTC");
	TXLifeRequest.OLifE.Holding[1].Policy.LineOfBusiness.tc = toTXLife(MIR-POL-BUS-CLAS-CD, "LineOfBusiness");
	TXLifeRequest.OLifE.Holding[1].Policy.LineOfBusiness.Value = GetDescription(MIR-POL-BUS-CLAS-CD, "LineOfBusiness");
	TXLifeRequest.OLifE.Holding[1].Policy.ProductType.tc = toTXLife(MIR-POL-INS-TYP-CD, "ProductType");
	TXLifeRequest.OLifE.Holding[1].Policy.ProductType.Value = GetDescription(MIR-POL-INS-TYP-CD, "ProductType");
#J03034 The KeyValue "applicationNumber" is no longer used by Life Suite. We have to use the TackingID to populate the value of MIR-POL-APP-FORM-ID
#	IF MIR-POL-APP-FORM-ID != ""
#	{
#		KeyIdx = KeyIdx + 1;
#		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "applicationNumber";
#		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = MIR-POL-APP-FORM-ID;
#	}
#J03034
	IF MIR-RLTED-POL-ID != ""
	{
		KeyIdx = KeyIdx + 1;
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "CaseGroupId";
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = MIR-RLTED-POL-ID;
	}
	ELSE
	{
		KeyIdx = KeyIdx + 1;
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "CaseGroupId";
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = UPPER(MIR-POL-ID-BASE) + UPPER(MIR-POL-ID-SFX);
 	}	
# 		................. Read BF1420-P to get the agency code to Assigned Team ..........................
# J03034 begin - 14FEB2013 - la valeur du champ "MIR-AGT-TEAM-ASIGN-CD" n'est plus transféré.
	STEP GetAgentInfo
	{
		USES P-STEP "BF1420-P";
		MIR-SERV-AGT-ID -> MIR-AGT-ID;
		BranchID <- MIR-BR-ID;
	}
#J03592 - J03598 Begin
# Par le biais du P-STEP BF0684-P charger dans un tableau vituel le contenu de la sous-table d'edit "BRCHLS" selon la langue de l'uilisateur utilisé.
# Si le code d'agence contenu à la variable "BranchID" est trouvé dans le tableau virtuel, alors
# La valeur de la variable "BranchID" sera remplacée par la valeur du champ EtblDescText-T[WS-IND].
# Si le code d'agence contenu à la variable "BranchID" n'est pas trouvé au tableau virtuel, alors
# La valeur de la variable "BranchID" restera inchangée.
# TRACE ( " BranchID = : " + BranchID);

	STEP TARGET4560
	{
		USES P-STEP "BF0684-P";
		ATTRIBUTES
		{
#			Explicit;
			GetMessages = "No";
		}
		"BRCHLS" -> MIR-ETBL-TYP-ID;
		"" -> MIR-ETBL-VALU-ID;
		"" -> MIR-ETBL-DESC-TXT;
		SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
	}
	WS-IND = 1;
	WHILE (MIR-ETBL-VALU-ID-T[WS-IND] != "")
	{
		IF MIR-ETBL-VALU-ID-T[WS-IND] == BranchID 
		{
			BranchID = MIR-ETBL-DESC-TXT-T[WS-IND];
		}
		WS-IND = WS-IND + 1;
	}
# TRACE ( " BranchID = : " + BranchID);

#J03592 - J03598 Ended
	
#	IF MIR-AGT-TEAM-ASIGN-CD != ""
#	{
#		KeyIdx = KeyIdx + 1;
#		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "assignedTeam";
#		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = MIR-AGT-TEAM-ASIGN-CD;
#	}

	KeyIdx = KeyIdx + 1;
	TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "GeneralNotes";
	IF SESSION.LSIR-USER-LANG-CD == "F"
	{
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = "La proposition a été saisie par " + SESSION.MIR-USER-ID;
	}
	ELSE
	{
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = "This proposal was entered by " + SESSION.MIR-USER-ID;
	}

	# Get the comment text on the policy
	IF MIR-POL-COMNT-TXT != ""
	{
		KeyIdx = KeyIdx + 1;
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "GeneralNotes";
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = MIR-POL-COMNT-TXT;
	}
	# Check if more than one owner on the contract. If so send info message at screen and TC103 XML.
	IF ( (MIR-CLI-ID-T[2] != "" && MIR-DV-OWN-SUB-CD-T[2] != "C") || (MIR-CLI-ID-T[3] != "" && MIR-DV-OWN-SUB-CD-T[3] != "C") || (MIR-CLI-ID-T[4] != "" && MIR-DV-OWN-SUB-CD-T[4] != "C") || (MIR-CLI-ID-T[5] != "" && MIR-DV-OWN-SUB-CD-T[5] != "C") )
	{
		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
		{
			MsgsIdx = MsgsIdx + 1;
		}
		# More than 1 owner on the contract. 
		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600002";

		KeyIdx = KeyIdx + 1;
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "GeneralNotes";
		IF SESSION.LSIR-USER-LANG-CD == "F"
		{
			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = "*** Attention *** Il y a plus d'un propriétaire sur le contrat *** Attention ***";
		}
		ELSE
		{
			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = "*** Attention *** There is more than one owner on the policy *** Attention ***";
		}
	}
#J03692 Begin
#BLFS-201 comment out the following code and see it later in logic.
#		IF MIR-POL-CNTCT-VIP-IND == "Y"
#		{
#			KeyIdx = KeyIdx + 1;
#			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "Priority";
#			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = "1";
#			priorityKeyIdx = KeyIdx;
#		}
#		ELSE
#		{
			KeyIdx = KeyIdx + 1;
			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyName = "Priority";
#BLFS-201			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = "2";
			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[KeyIdx].KeyValue = "11";
			priorityKeyIdx = KeyIdx;
#		}
#BLSF-201 End of comment out.		
#J03692 ENDED
	# .
	# .
	# .         ...................    build "OLifE.Holding.Policy.ApplicationInfo" tags    ............
	# .
	# .	
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.HOReceiptDate = MIR-POL-APP-RECV-DT;
#	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.TrackingID = "VPI-APP-13";
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.TrackingID = MIR-POL-APP-FORM-ID;
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.AppProposedInsuredSignatureOK.tc = toTXLife(MIR-POL-APP-SIGN-IND, "Boolean");
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.AppProposedInsuredSignatureOK.Value = GetDescription(MIR-POL-APP-SIGN-IND, "Boolean");
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.SignedDate = MIR-POL-APP-SIGN-DT;
#	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.BlanketAuthorizationInd.tc = toTXLife(MIR-POL-MIB-SIGN-CD, "Boolean");
#	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.BlanketAuthorizationInd.Value = GetDescription(MIR-POL-MIB-SIGN-CD, "Boolean");
#J03034 begin
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.ApplicationType.tc = toTXLife(MIR-POL-ELEC-PRPS-IND, "ApplicationType");
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.ApplicationType.Value = GetDescription(MIR-POL-ELEC-PRPS-IND, "ApplicationType");
#J03034 endded
	# 		................. Read BF1220-P to get the prefer language of the owner ..........................
	STEP GetOwnerInfo
	{
		USES P-STEP "BF1220-P";
		MIR-CLI-ID-T[1] -> MIR-CLI-ID;
		"N" -> MIR-CHCK-CLI-CNFD-IND;
	}
	OwnerId = MIR-CLI-ID-T[1];
	SecondOwnerId = MIR-CLI-ID-T[2];
	
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.PrefLanguage.tc = toTXLife(MIR-CLI-LANG-CD, "PrefLanguage");
	TXLifeRequest.OLifE.Holding[1].Policy.ApplicationInfo.PrefLanguage.Value = GetDescription(MIR-CLI-LANG-CD, "PrefLanguage");

	#**************************************************
	# Collect all information for Coverage management. 
	#************************************************** 
	# .
	# .                ............     Apply Life SUite's guarantee rules     ..........
	# .
	# .
	# .

	# Initialize working storage variables
	reccounter = 1;
	cvgindex = 1;
	AxaLifePrfCtr = 0;
	AxaLifeCtr = 0;
	GuarNum = 1;
	WHILE GuarNum <= 50
	{
		CvgGuarType-T[GuarNum] = "";
		CvgPurposeCd-T[GuarNum] = "";
		CvgStatusCd-T[GuarNum] = "";
		CvgFaceAmt-T[GuarNum] = 0;
		PolGrsApremAmt-T[GuarNum] = "";
		CvgCovNum-T[GuarNum] = "";
		CvgCovNumConn-T[GuarNum] = "";
		CvgInsrdRtAge[GuarNum] = "";
		CvgInsrdClassCd-T[GuarNum] = "";
		CvgInsrdSmokeCd-T[GuarNum] = "";
		CvgInsrdId-T[GuarNum] = "";
		CvgInsrdNm-T[GuarNum] = "";
		CvgGuarLsCd-T[GuarNum] = "";
		CvgFeUpremAmt-T[GuarNum] = "";
		CvgFeUpremEndDt-T[GuarNum] = "";
		CvgCovOptIndex-T[Guarnum] = 0;
		GuarNum = GuarNum + 1;
	}
	GuarNum = 1;

	# Loop all coverages on the policy and create an array according Life Suite's rules.

	WHILE reccounter <= NUMBER(MIR-POL-CVG-REC-CTR)
	{
		# Build the coverage number for INGENIUM. It needs to be a 2 character string.
		IF reccounter < 10
		{
			CvgNum = "0" + reccounter;
		}
		ELSE
		{
			CvgNum = reccounter;
		}
		MIR-CVG-NUM = CvgNum;

		# Use BF8020 Coverage Inquiry - All Details to retrieve information for this coverage.
		STEP TARGET8236
		{
			USES P-STEP "BF8020-P";
			PlanID <- MIR-PLAN-ID;
		}
		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03"
		{
			WS-DV-TRGR-SW = "OFF";
			BRANCH ContractRetrieve;	
		}
		# Check if the Type of Insurance Code, it's not 'F', 'M', 'N'. We must use the insurance coverages only.
		IF MIR-CVG-INS-TYP-CD != "N" && MIR-CVG-INS-TYP-CD != "M" && MIR-CVG-INS-TYP-CD != "F"
		{
			# Get the associated guarantee Life Suite's code in PH table 
			STEP TARGET1010
			{
				USES P-STEP "BF1810-P";
				PlanID -> MIR-PLAN-ID;
			}
			
			IF MIR-LS-UW-CAT-ID == "BLOCK"
			{
				#This contract contains a product no longer supported - Coverage @1. Process stopped.
				WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
				{
					MsgsIdx = MsgsIdx + 1;
				}
					MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600035";
					MIR-MSG-PARM-INFO-1-T[MsgsIdx] = PlanID;
					MIR-MSG-PARM-INFO-2-T[MsgsIdx] = MIR-CVG-NUM;
					WS-CVG-ERROR = "1";
					BRANCH TARGET1099;
			}
			
			IF MIR-LS-UW-CAT-ID == "NONE" || MIR-LS-UW-CAT-ID == ""
			{
				BRANCH TARGET1099;
			}
			WS-Additional-CovBnfit = "";
			IF SUBSTRING(MIR-LS-UW-CAT-ID, 1, 5) == "AXADI"
			{
				WS-Additional-CovBnfit = SUBSTRING(MIR-LS-UW-CAT-ID, 7, 2);
				MIR-LS-UW-CAT-ID = SUBSTRING(MIR-LS-UW-CAT-ID, 1, 5);
			}
			IF SUBSTRING(MIR-LS-UW-CAT-ID, 1, 7) == "AXLFHYP"
			{
				WS-Additional-CovBnfit = SUBSTRING(MIR-LS-UW-CAT-ID, 9, 2);
				MIR-LS-UW-CAT-ID = SUBSTRING(MIR-LS-UW-CAT-ID, 1, 7);
			}
			IF WS-FRST-CVG == 0
			{
				WS-FRST-LS-UW-CAT-ID = MIR-LS-UW-CAT-ID;
				WS-FRST-CVG = 1;
			}
			WS-PREV-LS-UW-CAT-ID = "";
			#**********************************************************************************************
			#* 		---	Garantie Vie & Vie Préférentielle	---   	                       
			#**********************************************************************************************
			IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" || MIR-LS-UW-CAT-ID == "AXALIFE"
			{
#J06116			IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(MIR-CVG-FACE-AMT) < 250000
				IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(MIR-CVG-FACE-AMT) < 500000
				{
					MIR-LS-UW-CAT-ID = "AXALIFE";
				}
				#---------------------------------------------------------------------------------------------------
				# - La condition Suivante va créer la première garantie LS  AXAVIE ou AXAPREF                          
				# - Des garanties complémentaires peuvent aussi être créées                                                    
				# - On passe à travers cette condition lors d'une première lecture AXALIFE ou AXALIFEPRF
				#---------------------------------------------------------------------------------------------------
				IF AxaLifePrfCtr == 0 && AxaLifeCtr == 0
				{
					index = 1;
					WHILE MIR-INSRD-CLI-ID-T[index] != ""
					{
						STEP TARGET1009
						{
							USES P-STEP "BF1220-P";
							MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
							"N" -> MIR-CHCK-CLI-CNFD-IND;
						}
						IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
						{
							WS-DV-TRGR-SW = "OFF";
							BRANCH ContractRetrieve;
						}
						#*****************************************************************************************
						# Si un assuré est un enfant à naître, créer la garantie complémataire - (57 - Child to be born ) 
						# qui doit être rattaché à l'assuré principal de la même couverture.
						#*****************************************************************************************
						IF MIR-CLI-INDV-GIV-NM-T[1] == "ENFANT DE" || MIR-CLI-INDV-GIV-NM-T[1] == "CHILD OF"
						{
							CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
							CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptTypeCode = "57";
							CvgCovOptIndex-T[GuarNum - index + 1] = CBindex;
							STEP TARGET4585
							{
								USES P-STEP "BF0680-P";
								ATTRIBUTES
								{
									Explicit;
									GetMessages = "No";
								}
								"GUARLS" -> MIR-ETBL-TYP-ID;
								"57" -> MIR-ETBL-VALU-ID;
								SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
								Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
							}
							CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
							CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptAmt = 0;
							CvgCovOptIndex-T[GuarNum - index + 1] = CBindex;
							BRANCH TARGET1012;
						}
						CvgGuarType-T[GuarNum] = "COVERAGE";
						CvgGuarLsCd-T[GuarNum] = MIR-LS-UW-CAT-ID;
						CvgInsrdId-T[GuarNum] = MIR-INSRD-CLI-ID-T[index];
						CvgPurposeCd-T[GuarNum] = MIR-POL-INS-PURP-CD;
						CvgStatusCd-T[GuarNum] = MIR-CVG-CSTAT-CD;
						CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index];
						CvgFaceAmt-T[GuarNum] = CvgFaceAmt-T[GuarNum] + NUMBER(MIR-CVG-FACE-AMT);
						PolGrsApremAmt-T[GuarNum] = MIR-POL-GRS-APREM-AMT;
						CvgCovNum-T[GuarNum] = MIR-CVG-NUM;
						CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
						CvgFeUpremAmt-T[GuarNum] = MIR-CVG-FE-UPREM-AMT;
						CvgFeUpremEndDt-T[GuarNum] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
						CvgInsrdNm-T[GuarNum] = MIR-DV-INSRD-CLI-NM-T[index];
#J04226						IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(MIR-CVG-FACE-AMT) >= 250000 && (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) >= 18)
#J06116						IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(MIR-CVG-FACE-AMT) >= 250000 && (NUMBER(MIR-INSRD-RT-AGE-T[index]) >= 18)
						IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(MIR-CVG-FACE-AMT) >= 500000 && (NUMBER(MIR-INSRD-RT-AGE-T[index]) >= 18)
						{
							IF MIR-INSRD-SMKR-CD-T[index] == "N"
							{
								CvgInsrdClassCd-T[GuarNum] = "Class 3 Non-Smoker";
							}
							IF MIR-INSRD-SMKR-CD-T[index] == "S" || ( (MIR-INSRD-STBL-2-CD-T[index] == "04" && MIR-CVG-STBL-2-CD == "04" && MIR-INSRD-SMKR-CD-T[index] == "N") || (MIR-INSRD-STBL-2-CD-T[index] == "" && MIR-CVG-STBL-2-CD == "04" && MIR-INSRD-SMKR-CD-T[index] == "N") || (MIR-INSRD-STBL-2-CD-T[index] == "04" && MIR-CVG-STBL-2-CD == "" && MIR-INSRD-SMKR-CD-T[index] == "N") )
							{
								CvgInsrdClassCd-T[GuarNum] = "Class 2 Smoker";
							}
						}
						CvgInsrdSmokeCd-T[GuarNum] = MIR-INSRD-SMKR-CD-T[index];
						#**********************************************************************************************
						#* 		---	Garantie complémentaire 50 MG & GA	---   	  
						#* Si la couverture contient au moin un assuré de moins de 18 ans et que le type de coût d'assurance
						#* est 'H', 'T', 'U', 'V' ou 'W' ont créer alors une garantie Complémentaire de type '50'.
						#**********************************************************************************************
#J03998						IF (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD =="W")
#J04226						IF (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W" || MIR-PLAN-COI-TYP-CD == "U")
 						IF (NUMBER(MIR-INSRD-RT-AGE-T[index]) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W" || MIR-PLAN-COI-TYP-CD == "U")
						{
							CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeCode = "50";
							STEP TARGET4576
							{
								USES P-STEP "BF0680-P";
								ATTRIBUTES
								{
									Explicit;
									GetMessages = "No";
								}
								"GUARLS" -> MIR-ETBL-TYP-ID;
								"50" -> MIR-ETBL-VALU-ID;
								SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
								Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
							}
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptAmt = 0;
							CvgCovOptIndex-T[GuarNum] = CBindex;
						}
						#**********************************************************************************************
						#* 		---	Garantie complémentaire 55 Indexation (5%-8%)	---   	
						#* Si la couverture est indexée ont créer alors une garantie Complémentaire de type '55'.
						#**********************************************************************************************
						IF MIR-CVG-ENHC-TYP-CD == "C" || MIR-CVG-ENHC-TYP-CD == "S" || MIR-CVG-NOTI-REASN-CD == "N2"
						{
							CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeCode = "55";
							CvgCovOptIndex-T[GuarNum] = CBindex;
							STEP TARGET4577
							{
								USES P-STEP "BF0680-P";
								ATTRIBUTES
								{
									Explicit;
									GetMessages = "No";
								}
								"GUARLS" -> MIR-ETBL-TYP-ID;
								"55" -> MIR-ETBL-VALU-ID;
								SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
								Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
							}
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptAmt = 0;
							CvgCovOptIndex-T[GuarNum] = CBindex;
						}
						GuarNum = GuarNum + 1;
						TARGET1012:
						index = index +1;
					}
					IF MIR-LS-UW-CAT-ID == "AXALIFEPRF"
					{
						AxaLifePrfCtr = 1;
					}
					ELSE
					{
						AxaLifeCtr = 1;
					}
				}
				#---------------------------------------------------------------------------------------------------
				# La condition ESLE permet le regroupement s'il y lieu des couvertures AVAVIE &	AXAPREF 
				# par assuré de chaque couverture.
				# Des garanties complémentaires peuvent aussi être créées
				# - On passe à travers cette condition lors d'une 2ieme lecture ou plus de  AXALIFE ou AXALIFEPRF
				#----------------------------------------------------------------------------------------------------
				ELSE
				{
					index = 1;
					WHILE MIR-INSRD-CLI-ID-T[index] != ""
 					{
						STEP TARGET1011
						{
							USES P-STEP "BF1220-P";
							MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
							"N" -> MIR-CHCK-CLI-CNFD-IND;
						}
						IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
						{
							WS-DV-TRGR-SW = "OFF";
							BRANCH ContractRetrieve;
						}
						#*****************************************************************************************
						# Si un assuré est un enfant à naître, créer la garantie complémataire - (57 - Child to be born ) 
						# qui doit être rattaché à l'assuré principal de la même couverture.
						#*****************************************************************************************
						IF MIR-CLI-INDV-GIV-NM-T[1] == "ENFANT DE" || MIR-CLI-INDV-GIV-NM-T[1] == "CHILD OF"
						{
							CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
							CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptTypeCode = "57";
							CvgCovOptIndex-T[GuarNum - index + 1] = CBindex;
							STEP TARGET4584
							{
								USES P-STEP "BF0680-P";
								ATTRIBUTES
								{
									Explicit;
									GetMessages = "No";
								}
								"GUARLS" -> MIR-ETBL-TYP-ID;
								"57" -> MIR-ETBL-VALU-ID;
								SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
								Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
							}
							CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
							CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptAmt = 0;
							CvgCovOptIndex-T[GuarNum - index + 1] = CBindex;
							BRANCH TARGET1014;
						}
						InsrdFound = "N";
						CvgInsrdCtr = 1;
						WHILE CvgInsrdId-T[CvgInsrdCtr] != ""
						{
							IF CvgInsrdId-T[CvgInsrdCtr] == MIR-INSRD-CLI-ID-T[index] && (CvgGuarLsCd-T[CvgInsrdCtr] == "AXALIFE" || CvgGuarLsCd-T[CvgInsrdCtr] == "AXALIFEPRF")
							{
								CvgFaceAmt-T[CvgInsrdCtr] = CvgFaceAmt-T[CvgInsrdCtr] + NUMBER(MIR-CVG-FACE-AMT);
								CvgCovNum-T[CvgInsrdCtr] = CvgCovNum-T[CvgInsrdCtr] + MIR-CVG-NUM ;
								IF CvgGuarLsCd-T[CvgInsrdCtr] == "AXALIFE" && MIR-LS-UW-CAT-ID == "AXALIFEPRF"
								{
									CvgGuarLsCd-T[CvgInsrdCtr] = MIR-LS-UW-CAT-ID;
								}
								InsrdFound = "Y";
#J04226								IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(CvgFaceAmt-T[CvgInsrdCtr]) >= 250000 && (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) >= 18)
#J06116								IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(CvgFaceAmt-T[CvgInsrdCtr]) >= 250000 && (NUMBER(MIR-INSRD-RT-AGE-T[index]) >= 18)
								IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(CvgFaceAmt-T[CvgInsrdCtr]) >= 500000 && (NUMBER(MIR-INSRD-RT-AGE-T[index]) >= 18)
								{
									IF MIR-INSRD-SMKR-CD-T[index] == "N"
									{
										CvgInsrdClassCd-T[CvgInsrdCtr] = "Class 3 Non-Smoker";
									}
									IF MIR-INSRD-SMKR-CD-T[index] == "S" || ( (MIR-INSRD-STBL-2-CD-T[index] == "04" && MIR-CVG-STBL-2-CD == "04" && MIR-INSRD-SMKR-CD-T[index] == "N") || (MIR-INSRD-STBL-2-CD-T[index] == "" && MIR-CVG-STBL-2-CD == "04" && MIR-INSRD-SMKR-CD-T[index] == "N") || (MIR-INSRD-STBL-2-CD-T[index] == "04" && MIR-CVG-STBL-2-CD == "" && MIR-INSRD-SMKR-CD-T[index] == "N") )
									{
										CvgInsrdClassCd-T[CvgInsrdCtr] = "Class 2 Smoker";
									}
								}
								#**********************************************************************************************
								#* 		---	Garantie complémentaire 50 MG & GA	---   	  
								#* Si la couverture contient au moin un assuré de moins de 18 ans et que le type de coût d'assurance
								#* est 'H', 'T', 'U', 'V'ou 'W' ont créer alors une garantie Complémentaire de type '50'.
								#**********************************************************************************************
#J03998								IF (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W")
#J04226								IF (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W" || MIR-PLAN-COI-TYP-CD == "U")
								IF (NUMBER(MIR-INSRD-RT-AGE-T[index]) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W" || MIR-PLAN-COI-TYP-CD == "U")
								{
									CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeCode = "50";
									STEP TARGET4578
									{
										USES P-STEP "BF0680-P";
										ATTRIBUTES
										{
											Explicit;
											GetMessages = "No";
										}
										"GUARLS" -> MIR-ETBL-TYP-ID;
										"50" -> MIR-ETBL-VALU-ID;
										SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
										Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
									}
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = 0;
									CvgCovOptIndex-T[CvgInsrdCtr] = CBindex;
								}
								#**********************************************************************************************
								#* 		---	Garantie complémentaire 55 Indexation (5%-8%)	---   	
								#* Si la couverture est indexée ont créer alors une garantie Complémentaire de type '55'.
								#**********************************************************************************************
								IF MIR-CVG-ENHC-TYP-CD == "C" || MIR-CVG-ENHC-TYP-CD == "S" || MIR-CVG-NOTI-REASN-CD == "N2"
								{
									CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeCode = "55";
									STEP TARGET4583
									{
										USES P-STEP "BF0680-P";
										ATTRIBUTES
										{
											Explicit;
											GetMessages = "No";
										}
										"GUARLS" -> MIR-ETBL-TYP-ID;
										"55" -> MIR-ETBL-VALU-ID;
										SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
										Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
									}
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = 0;
									CvgCovOptIndex-T[CvgInsrdCtr] = CBindex;
								}
							}
							CvgInsrdCtr = CvgInsrdCtr + 1;
						}
						IF InsrdFound == "N"
						{
							STEP TARGET1013
							{
								USES P-STEP "BF1220-P";
								MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
								"N" -> MIR-CHCK-CLI-CNFD-IND;
							}
							IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
							{
								WS-DV-TRGR-SW = "OFF";
								BRANCH ContractRetrieve;
							}
							CvgGuarType-T[GuarNum] = "COVERAGE";
							CvgGuarLsCd-T[GuarNum] = MIR-LS-UW-CAT-ID;
							CvgInsrdId-T[GuarNum] = MIR-INSRD-CLI-ID-T[index];
							CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index]; 
							CvgPurposeCd-T[GuarNum] = MIR-POL-INS-PURP-CD;
							CvgStatusCd-T[GuarNum] = MIR-CVG-CSTAT-CD;
							CvgFaceAmt-T[GuarNum] = CvgFaceAmt-T[GuarNum] + NUMBER(MIR-CVG-FACE-AMT);
							PolGrsApremAmt-T[GuarNum] = MIR-POL-GRS-APREM-AMT;
							CvgCovNum-T[GuarNum] = MIR-CVG-NUM;
							CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
#J06116							IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(CvgFaceAmt-T[GuarNum]) >= 250000
							IF MIR-LS-UW-CAT-ID == "AXALIFEPRF" && NUMBER(CvgFaceAmt-T[GuarNum]) >= 500000
							{
								IF MIR-INSRD-SMKR-CD-T[index] == "N"
								{
									CvgInsrdClassCd-T[CvgInsrdCtr] = "Class 3 Non-Smoker";
								}
								IF MIR-INSRD-SMKR-CD-T[index] == "S" || ( (MIR-INSRD-STBL-2-CD-T[index] == "04" && MIR-CVG-STBL-2-CD == "04" && MIR-INSRD-SMKR-CD-T[index] == "N") || (MIR-INSRD-STBL-2-CD-T[index] == "" && MIR-CVG-STBL-2-CD == "04" && MIR-INSRD-SMKR-CD-T[index] == "N") || (MIR-INSRD-STBL-2-CD-T[index] == "04" && MIR-CVG-STBL-2-CD == "" && MIR-INSRD-SMKR-CD-T[index] == "N") )
								{
									CvgInsrdClassCd-T[CvgInsrdCtr] = "Class 2 Smoker";
								}
							}
							CvgInsrdSmokeCd-T[GuarNum] = MIR-INSRD-SMKR-CD-T[index];
							CvgFeUpremAmt-T[GuarNum] = MIR-CVG-FE-UPREM-AMT;
							CvgFeUpremEndDt-T[GuarNum] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
							CvgInsrdNm-T[GuarNum] = MIR-DV-INSRD-CLI-NM-T[index];
							#**********************************************************************************************
							#* 		---	Garantie complémentaire 50 MG & GA.
							#* Si la couverture contient au moin un assuré de moins de 18 ans et que le type de coût d'assurance
							#* est 'H', 'T', 'U', 'V'ou 'W' ont créer alors une garantie Complémentaire de type '50'.
							#**********************************************************************************************
#J03998							IF (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W")
#J04226							IF (NUMBER(SUBSTRING(MIR-DV-EFF-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CLI-BTH-DT, 1, 4)) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W" || MIR-PLAN-COI-TYP-CD == "U")
							IF (NUMBER(MIR-INSRD-RT-AGE-T[index]) < 18) && (MIR-PLAN-COI-TYP-CD == "H" || MIR-PLAN-COI-TYP-CD == "T" || MIR-PLAN-COI-TYP-CD == "V" || MIR-PLAN-COI-TYP-CD == "W" || MIR-PLAN-COI-TYP-CD == "U")
							{
								CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
								CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeCode = "50";
								STEP TARGET4582
								{
									USES P-STEP "BF0680-P";
									ATTRIBUTES
									{
										Explicit;
										GetMessages = "No";
									}
									"GUARLS" -> MIR-ETBL-TYP-ID;
									"50" -> MIR-ETBL-VALU-ID;
									SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
									Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
								}
								CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
								CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptAmt = 0;
								CvgCovOptIndex-T[GuarNum] = CBindex;
							}
							#**********************************************************************************************
							#* 		---	Garantie complémentaire 55 Indexation (5%-8%)
							#* Si la couverture est indexée ont créer alors une garantie Complémentaire de type '55'.
							#**********************************************************************************************
							IF MIR-CVG-ENHC-TYP-CD == "C" || MIR-CVG-ENHC-TYP-CD == "S" || MIR-CVG-NOTI-REASN-CD == "N2"
							{
								CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
								CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeCode = "55";
								STEP TARGET4579
								{
									USES P-STEP "BF0680-P";
									ATTRIBUTES
									{
										Explicit;
										GetMessages = "No";
									}
									"GUARLS" -> MIR-ETBL-TYP-ID;
									"55" -> MIR-ETBL-VALU-ID;
									SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
									Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
								}
								CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
								CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptAmt = 0;
								CvgCovOptIndex-T[GuarNum] = CBindex;
							}
							GuarNum = GuarNum + 1;
						}
						TARGET1014:
						index = index +1;
					}
				}
			}
			#**********************************************************************************************
			#* 		---	Garantie Vie TempoFlex	---                             
			#**********************************************************************************************
			IF MIR-LS-UW-CAT-ID == "AXALIFEFLX"
			{
				index = 1;
				WHILE MIR-INSRD-CLI-ID-T[index] != ""
				{
					STEP TARGET1020
					{
						USES P-STEP "BF1220-P";
						MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
						"N" -> MIR-CHCK-CLI-CNFD-IND;
					}
					IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
					{
						WS-DV-TRGR-SW = "OFF";
						BRANCH ContractRetrieve;
					}
					CvgGuarType-T[GuarNum] = "COVERAGE";
					CvgGuarLsCd-T[GuarNum] = MIR-LS-UW-CAT-ID;
					CvgInsrdId-T[GuarNum] = MIR-INSRD-CLI-ID-T[index];
					CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index]; 
					CvgPurposeCd-T[GuarNum] = MIR-POL-INS-PURP-CD;
					CvgStatusCd-T[GuarNum] = MIR-CVG-CSTAT-CD;
					IF MIR-CVG-STBL-4-CD != ""
					{
						CvgFaceAmt-T[GuarNum] = (NUMBER(MIR-CVG-FACE-AMT) / (1 + (NUMBER(MIR-CVG-STBL-4-CD) / 100)));
					}
					ELSE
					{
						CvgFaceAmt-T[GuarNum] = MIR-CVG-FACE-AMT;
					}
					PolGrsApremAmt-T[GuarNum] = MIR-POL-GRS-APREM-AMT;
					CvgCovNum-T[GuarNum] = MIR-CVG-NUM;
					CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
					CvgInsrdClassCd-T[GuarNum] = MIR-INSRD-STBL-2-CD-T[index];
					CvgInsrdSmokeCd-T[GuarNum] = MIR-INSRD-SMKR-CD-T[index];
					CvgFeUpremAmt-T[GuarNum] = MIR-CVG-FE-UPREM-AMT;
					CvgFeUpremEndDt-T[GuarNum] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
					CvgInsrdNm-T[GuarNum] = MIR-DV-INSRD-CLI-NM-T[index];
					GuarNum = GuarNum + 1;
					TARGET1019:
					index = index + 1;
				}
			}
			#**********************************************************************************************
			#* 		---	Garantie Vie Hypotoît	---                              
			#**********************************************************************************************
			IF MIR-LS-UW-CAT-ID == "AXLFHYP"
			{
				MIR-CVG-XPRY-AGE-DUR = NUMBER(SUBSTRING(MIR-CVG-MAT-XPRY-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4));
				WS-PREV-LS-UW-CAT-ID = MIR-LS-UW-CAT-ID;
				index = 1;
				WHILE MIR-INSRD-CLI-ID-T[index] != ""
				{
					STEP TARGET1021
					{
						USES P-STEP "BF1220-P";
						MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
						"N" -> MIR-CHCK-CLI-CNFD-IND;
					}
					IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
					{
						WS-DV-TRGR-SW = "OFF";
						BRANCH ContractRetrieve;
					}
					CvgGuarType-T[GuarNum] = "COVERAGE";
					CvgGuarLsCd-T[GuarNum] = MIR-LS-UW-CAT-ID;
					CvgInsrdId-T[GuarNum] = MIR-INSRD-CLI-ID-T[index];
					CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index]; 
					CvgPurposeCd-T[GuarNum] = MIR-POL-INS-PURP-CD;
					CvgStatusCd-T[GuarNum] = MIR-CVG-CSTAT-CD;
					IF MIR-CVG-XPRY-AGE-DUR == 15
					{
						CvgFaceAmt-T[GuarNum] = (WsHypotoitDurAmt15 * (NUMBER(MIR-CVG-FACE-AMT) / 100));
					}
					IF MIR-CVG-XPRY-AGE-DUR == 20
					{
						CvgFaceAmt-T[GuarNum] = (WsHypotoitDurAmt20 * (NUMBER(MIR-CVG-FACE-AMT) / 100));
					}
					IF MIR-CVG-XPRY-AGE-DUR == 25
					{
						CvgFaceAmt-T[GuarNum] = (WsHypotoitDurAmt25 * (NUMBER(MIR-CVG-FACE-AMT) / 100));
					}
					PolGrsApremAmt-T[GuarNum] = MIR-POL-GRS-APREM-AMT;
					CvgCovNum-T[GuarNum] = MIR-CVG-NUM;
					CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
					CvgInsrdClassCd-T[GuarNum] = MIR-INSRD-STBL-2-CD-T[index];
					CvgInsrdSmokeCd-T[GuarNum] = MIR-INSRD-SMKR-CD-T[index];
					CvgFeUpremAmt-T[GuarNum] = MIR-CVG-FE-UPREM-AMT;
					CvgFeUpremEndDt-T[GuarNum] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
					CvgInsrdNm-T[GuarNum] = MIR-DV-INSRD-CLI-NM-T[index];
					GuarNum = GuarNum + 1;
					TARGET1018:
					index = index + 1;
				}
				MIR-LS-UW-CAT-ID = WS-Additional-CovBnfit;
			}
			#**********************************************************************************************
			#* 		---	Garantie Horizon Santé	---                             
			#* Pour cette garantie la couverture qui contient le plus grand capitale nominal     
			#* Doit devenir la première garantie AXADI.
			#* Le principe de plusieurs assurés par couverture n'est pas consdéré sur ce produit                                    
			#**********************************************************************************************
			IF MIR-LS-UW-CAT-ID == "AXADI"
			{
				WS-IndDisabilityPlan = "Y";
				index = 1;
				IF NUMBER(MIR-CVG-FACE-AMT) > GreaterCvgFaceAmt
				{
					CvgGuarType-T[1] = "COVERAGE";
					CvgGuarLsCd-T[1] = MIR-LS-UW-CAT-ID;
					CvgInsrdId-T[1] = MIR-INSRD-CLI-ID-T[index];
					CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index]; 
					CvgPurposeCd-T[1] = MIR-POL-INS-PURP-CD;
					CvgStatusCd-T[1] = MIR-CVG-CSTAT-CD;
					CvgFaceAmt-T[1] = MIR-CVG-FACE-AMT;
					PolGrsApremAmt-T[1] = MIR-POL-GRS-APREM-AMT;
					CvgCovNum-T[1] = MIR-CVG-NUM;
					CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
					CvgInsrdClassCd-T[1] = MIR-INSRD-STBL-2-CD-T[index];
					CvgInsrdSmokeCd-T[1] = MIR-INSRD-SMKR-CD-T[index];
					CvgFeUpremAmt-T[1] = MIR-CVG-FE-UPREM-AMT;
					CvgFeUpremEndDt-T[1] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
					CvgInsrdNm-T[1] = MIR-DV-INSRD-CLI-NM-T[index];
					GreaterCvgFaceAmt = NUMBER(MIR-CVG-FACE-AMT);
				}
				MIR-LS-UW-CAT-ID = WS-Additional-CovBnfit;
			}
			#**********************************************************************************************
			#* 		---	Garantie Maladie Grave - AXACI	---    
			#* 		---	Garantie Avenants jeunesses plus - AXAAJP 	---                             
			#* 		---	Garantie Avenants juvéniles - AXAAVJU	---                             
			#**********************************************************************************************
			IF MIR-LS-UW-CAT-ID == "AXACI" || MIR-LS-UW-CAT-ID == "AXAAJP" || MIR-LS-UW-CAT-ID == "AXAAVJU"  
			{
				index = 1;
				WHILE MIR-INSRD-CLI-ID-T[index] != ""
				{
					STEP TARGET1015
					{	
						USES P-STEP "BF1220-P";
						MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
						"N" -> MIR-CHCK-CLI-CNFD-IND;
					}
					IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
					{
						WS-DV-TRGR-SW = "OFF";
						BRANCH ContractRetrieve;
					}
					#*****************************************************************************************
					# For all AJP couverage type
					# Si un assuré est un enfant à naître, créer garantie complémataire - (57 - Child to be born ) 
					# qui doit être rattaché à l'assuré principal de la couverture de base.
					#*****************************************************************************************
					IF MIR-CLI-INDV-GIV-NM-T[1] == "ENFANT DE" || MIR-CLI-INDV-GIV-NM-T[1] == "CHILD OF"
					{
						CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
#						CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptTypeCode = "57";
#						CvgCovOptIndex-T[GuarNum - index + 1] = CBindex;
						CvgOption[1].CovBnfit[CBindex].LiveCovOptTypeCode = "57";
						CvgCovOptIndex-T[1] = CBindex;
						STEP TARGET4588
						{
							USES P-STEP "BF0680-P";
							ATTRIBUTES
							{
								Explicit;
								GetMessages = "No";
							}
							"GUARLS" -> MIR-ETBL-TYP-ID;
							"57" -> MIR-ETBL-VALU-ID;
							SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
							Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
						}
#						CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
#						CvgOption[GuarNum - index + 1].CovBnfit[CBindex].LiveCovOptAmt = 0;
#						CvgCovOptIndex-T[GuarNum - (index + 1)] = CBindex;
						CvgOption[1].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
						CvgOption[1].CovBnfit[CBindex].LiveCovOptAmt = NUMBER(MIR-CVG-FACE-AMT);
						CvgCovOptIndex-T[1] = CBindex;
#J04290 begin
						CvgCovNum-T[1] = CvgCovNum-T[1] + MIR-CVG-NUM ;
#J04290 ended
						BRANCH TARGET1016;
					}
					IF MIR-LS-UW-CAT-ID == "AXACI"
					{
						CvgInsrdCtr = 1;
						WHILE CvgInsrdId-T[CvgInsrdCtr] != ""
						{
							IF CvgInsrdId-T[CvgInsrdCtr] == MIR-INSRD-CLI-ID-T[index] && CvgGuarLsCd-T[CvgInsrdCtr] == "AXACI" 
							{
								CvgFaceAmt-T[CvgInsrdCtr] = CvgFaceAmt-T[CvgInsrdCtr] + NUMBER(MIR-CVG-FACE-AMT);
								CvgCovNum-T[CvgInsrdCtr] = CvgCovNum-T[CvgInsrdCtr] + MIR-CVG-NUM ;
								BRANCH TARGET1016;
							}
							CvgInsrdCtr = CvgInsrdCtr + 1;
						}
					}
					CvgGuarType-T[GuarNum] = "COVERAGE";
					CvgGuarLsCd-T[GuarNum] = MIR-LS-UW-CAT-ID;
					CvgInsrdId-T[GuarNum] = MIR-INSRD-CLI-ID-T[index];
					CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index]; 
					CvgPurposeCd-T[GuarNum] = MIR-POL-INS-PURP-CD;
					CvgStatusCd-T[GuarNum] = MIR-CVG-CSTAT-CD;
					CvgFaceAmt-T[GuarNum] = NUMBER(MIR-CVG-FACE-AMT);
					PolGrsApremAmt-T[GuarNum] = MIR-POL-GRS-APREM-AMT;
					CvgCovNum-T[GuarNum] = MIR-CVG-NUM;
					CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
					CvgInsrdClassCd-T[GuarNum] = MIR-INSRD-STBL-2-CD-T[index];
					CvgInsrdSmokeCd-T[GuarNum] = MIR-INSRD-SMKR-CD-T[index];
					CvgFeUpremAmt-T[GuarNum] = MIR-CVG-FE-UPREM-AMT;
					CvgFeUpremEndDt-T[GuarNum] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
					CvgInsrdNm-T[GuarNum] = MIR-DV-INSRD-CLI-NM-T[index];
					GuarNum = GuarNum + 1;
					TARGET1016:
					index = index +1;
				}
			}
			#**********************************************************************************************
			#* 		---	Garantie Vie Maxi Revenu Banque Nationale	---                              
			#**********************************************************************************************
			IF MIR-LS-UW-CAT-ID == "AXALIFEMAX"
			{
				MIR-CVG-XPRY-AGE-DUR = NUMBER(SUBSTRING(MIR-CVG-MAT-XPRY-DT, 1, 4)) - NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4));
				
				index = 1;
				WHILE MIR-INSRD-CLI-ID-T[index] != ""
				{
					STEP TARGET1023
					{
						USES P-STEP "BF1220-P";
						MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
						"N" -> MIR-CHCK-CLI-CNFD-IND;
					}
					IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
					{
						WS-DV-TRGR-SW = "OFF";
						BRANCH ContractRetrieve;
					}
					CvgGuarType-T[GuarNum] = "COVERAGE";
					CvgGuarLsCd-T[GuarNum] = MIR-LS-UW-CAT-ID;
					CvgInsrdId-T[GuarNum] = MIR-INSRD-CLI-ID-T[index];
					CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index]; 
					CvgPurposeCd-T[GuarNum] = MIR-POL-INS-PURP-CD;
					CvgStatusCd-T[GuarNum] = MIR-CVG-CSTAT-CD;
					IF MIR-CVG-XPRY-AGE-DUR == 15
					{
						CvgFaceAmt-T[GuarNum] = WsMaxiRevnuDurAmt15 * NUMBER(MIR-CVG-FACE-AMT);
					}
					IF MIR-CVG-XPRY-AGE-DUR == 20
					{
						CvgFaceAmt-T[GuarNum] = WsMaxiRevnuDurAmt20 * NUMBER(MIR-CVG-FACE-AMT);
					}
					IF MIR-CVG-XPRY-AGE-DUR == 25
					{
						CvgFaceAmt-T[GuarNum] = WsMaxiRevnuDurAmt25 * NUMBER(MIR-CVG-FACE-AMT);
					}
					PolGrsApremAmt-T[GuarNum] = MIR-POL-GRS-APREM-AMT;
					CvgCovNum-T[GuarNum] = MIR-CVG-NUM;
					CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
					CvgInsrdClassCd-T[GuarNum] = MIR-INSRD-STBL-2-CD-T[index];
					CvgInsrdSmokeCd-T[GuarNum] = MIR-INSRD-SMKR-CD-T[index];
					CvgFeUpremAmt-T[GuarNum] = MIR-CVG-FE-UPREM-AMT;
					CvgFeUpremEndDt-T[GuarNum] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
					CvgInsrdNm-T[GuarNum] = MIR-DV-INSRD-CLI-NM-T[index];
					GuarNum = GuarNum + 1;
					TARGET1024:
					index = index + 1;
				}
			}
			#**********************************************************************************************
			#* 		---	Garanties compémentaires	---    
			#* 		---	02, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64,65,66,67,68,70                             
			#**********************************************************************************************
			IF NUMBER(MIR-LS-UW-CAT-ID) > 0 &&  NUMBER(MIR-LS-UW-CAT-ID) <= 99
			{
				# Get the garantee name in EDIT table
				STEP TARGET4580
				{
					USES P-STEP "BF0680-P";
					ATTRIBUTES
					{
						Explicit;
						GetMessages = "No";
					}
					"GUARLS" -> MIR-ETBL-TYP-ID;
					MIR-LS-UW-CAT-ID -> MIR-ETBL-VALU-ID;
					SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
					Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
				}
				index = 1;
				WHILE MIR-INSRD-CLI-ID-T[index] != ""
				{
					STEP TARGET1022
					{	
						USES P-STEP "BF1220-P";
						MIR-INSRD-CLI-ID-T[index] -> MIR-CLI-ID;
						"N" -> MIR-CHCK-CLI-CNFD-IND;
					}
					IF LSIR-RETURN-CD == "01" || LSIR-RETURN-CD == "02" || LSIR-RETURN-CD == "05"
					{
						WS-DV-TRGR-SW = "OFF";
						BRANCH ContractRetrieve;
					}
					InsrdFound = "N";
					CvgInsrdCtr = 1;
					WHILE CvgInsrdId-T[CvgInsrdCtr] != "" && InsrdFound == "N"
					{
					IF CvgInsrdId-T[CvgInsrdCtr] == MIR-INSRD-CLI-ID-T[index] 
						{
#J3607 Begin
#							IF MIR-REL-CVG-NUM == CvgCovNumConn-T[CvgInsrdCtr]
							IF MIR-REL-CVG-NUM != "" && CvgInsrdId-T[CvgInsrdCtr] == MIR-INSRD-CLI-ID-T[index] 
#J3607 Ended
							{
								CvgCovNum-T[CvgInsrdCtr] = CvgCovNum-T[CvgInsrdCtr] + MIR-CVG-NUM;
								CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
								CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeCode = MIR-LS-UW-CAT-ID;
								CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
#BLFS-127								IF MIR-LS-UW-CAT-ID == "48" || MIR-LS-UW-CAT-ID == "53" || MIR-LS-UW-CAT-ID == "54" || MIR-LS-UW-CAT-ID == "65" || MIR-LS-UW-CAT-ID == "66" || MIR-LS-UW-CAT-ID == "67" || WS-IndDisabilityPlan == "Y"
								IF MIR-LS-UW-CAT-ID == "48" || MIR-LS-UW-CAT-ID == "53" 
															|| MIR-LS-UW-CAT-ID == "54" 
															|| MIR-LS-UW-CAT-ID == "65" 
															|| MIR-LS-UW-CAT-ID == "66" 
															|| MIR-LS-UW-CAT-ID == "67" 
															|| MIR-LS-UW-CAT-ID == "68" 
															|| MIR-LS-UW-CAT-ID == "70" 
															|| WS-IndDisabilityPlan == "Y"
#BLFS-127
								{
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = NUMBER(MIR-CVG-FACE-AMT);
								}
								ELSE
								{
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = 0;
								}
								CvgCovOptIndex-T[CvgInsrdCtr] = CBindex;
								InsrdFound = "Y";
							}
							ELSE 
							{
								IF MIR-REL-CVG-NUM == ""
								{
									CvgCovNum-T[CvgInsrdCtr] = CvgCovNum-T[CvgInsrdCtr] + MIR-CVG-NUM;
									CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeCode = MIR-LS-UW-CAT-ID;
									CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
#BLFS-127									IF MIR-LS-UW-CAT-ID == "48" || MIR-LS-UW-CAT-ID == "53" || MIR-LS-UW-CAT-ID == "54" || MIR-LS-UW-CAT-ID == "65" || MIR-LS-UW-CAT-ID == "66" || MIR-LS-UW-CAT-ID == "67" || WS-IndDisabilityPlan == "Y"
									IF MIR-LS-UW-CAT-ID == "48" || MIR-LS-UW-CAT-ID == "53" 
																|| MIR-LS-UW-CAT-ID == "54" 
																|| MIR-LS-UW-CAT-ID == "65" 
																|| MIR-LS-UW-CAT-ID == "66" 
																|| MIR-LS-UW-CAT-ID == "67" 
																|| MIR-LS-UW-CAT-ID == "68" 
																|| MIR-LS-UW-CAT-ID == "70" 
																|| WS-IndDisabilityPlan == "Y"
#BLFS-127
									{
										CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = NUMBER(MIR-CVG-FACE-AMT);
										IF WS-PREV-LS-UW-CAT-ID == "AXLFHYP"
										{
											CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = NUMBER(MIR-CVG-FACE-AMT);
#											CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = NUMBER(CvgFaceAmt-T[CvgInsrdCtr]);
										}
									}
									ELSE
									{
										CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = 0;
									}
									CvgCovOptIndex-T[CvgInsrdCtr] = CBindex;
									InsrdFound = "Y";
								}	
							}
						}
						CvgInsrdCtr = CvgInsrdCtr + 1;
					}
					IF InsrdFound == "N"
					{
						IF MIR-REL-CVG-NUM != ""
						{
							WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
							{
								MsgsIdx = MsgsIdx + 1;
							}
							#Guarantee benefit of cvg @2 is not related to the right cvg. Transfer request has failed.
							MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600037";
							MIR-MSG-PARM-INFO-1-T [MsgsIdx] = Guarantee-name;
							MIR-MSG-PARM-INFO-2-T [MsgsIdx] = MIR-CVG-NUM;
							WS-CVG-ERROR = "1";
							BRANCH TARGET1099;
						}
						ELSE
						{
							CvgGuarType-T[GuarNum] = "COVERAGE";
							CvgGuarLsCd-T[GuarNum] = WS-FRST-LS-UW-CAT-ID;
							CvgInsrdId-T[GuarNum] = MIR-INSRD-CLI-ID-T[index];
							CvgPurposeCd-T[GuarNum] = MIR-POL-INS-PURP-CD;
							CvgStatusCd-T[GuarNum] = MIR-CVG-CSTAT-CD;
							CvgInsrdRtAge[GuarNum] = MIR-INSRD-RT-AGE-T[index]; 
							CvgFaceAmt-T[GuarNum] = 0;
							PolGrsApremAmt-T[GuarNum] = MIR-POL-GRS-APREM-AMT;
							CvgCovNum-T[GuarNum] = MIR-CVG-NUM;
							CvgCovNumConn-T[GuarNum] = MIR-CVG-NUM;
							CvgInsrdClassCd-T[GuarNum] = MIR-INSRD-STBL-2-CD-T[index];
							CvgInsrdSmokeCd-T[GuarNum] = MIR-INSRD-SMKR-CD-T[index];
							CvgFeUpremAmt-T[GuarNum] = MIR-CVG-FE-UPREM-AMT;
							CvgFeUpremEndDt-T[GuarNum] = (NUMBER(SUBSTRING(MIR-CVG-ISS-EFF-DT, 1, 4)) + NUMBER(MIR-CVG-FE-DUR) + SUBSTRING(MIR-CVG-ISS-EFF-DT, 5, 6));
							CvgInsrdNm-T[GuarNum] = MIR-DV-INSRD-CLI-NM-T[index];
							CBindex = NUMBER(CvgCovOptIndex-T[CvgInsrdCtr]) + 1;
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeCode = MIR-LS-UW-CAT-ID;
							CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptTypeTxt = Guarantee-name;
							IF MIR-LS-UW-CAT-ID == "48" || MIR-LS-UW-CAT-ID == "53" || MIR-LS-UW-CAT-ID == "54" || MIR-LS-UW-CAT-ID == "65" || MIR-LS-UW-CAT-ID == "66" || MIR-LS-UW-CAT-ID == "67" || WS-IndDisabilityPlan == "Y"
							{
								CvgOption[GuarNum].CovBnfit[CBindex].LiveCovOptAmt = NUMBER(CvgFaceAmt-T[GuarNum]);
							}
							ELSE
							{
								CvgOption[CvgInsrdCtr].CovBnfit[CBindex].LiveCovOptAmt = 0;
							}
							CvgCovOptIndex-T[GuarNum] = CBindex;
							GuarNum = GuarNum + 1;
						}
					}
					TARGET1017:
					index = index + 1;
				}
			}
		}
		TARGET1099:
		reccounter = reccounter + 1;
	}	
	# ------------ Fin de la logique des règles sur les garanties -------
	
	#***********************************************************************************************************
	# À partir du tableau construit précédemment lequel contient la totalité des garanties et garanties complémentaires,
	# Constuire le fichier XML pour chaque garantie.
	# Si aucune garantie, ie. si le tableau est vide, le message XS9260 0009 sera envoyé à l'écran de sortie
	#*********************************************************************************************************** 
	# Si une erreur est trouvée dans le traitement des couvertures, générer les messages en appelant le WriteUserMessage
	IF WS-CVG-ERROR == "1"
	{
		BRANCH WriteUserMessage;
	}
	cvgindex = 1;
	IF CvgGuarType-T[cvgindex] == ""
	{
		#This contract contains no valid LifeSuite product.
		MIR-MSG-REF-INFO-T[1] = "XS92600009";
		BRANCH WriteUserMessage;
	}	
	# Loop through each guarantee on the array and guarantee Object for each one.
	WHILE CvgGuarType-T[cvgindex] != ""
	{
		IF CvgGuarLsCd-T[cvgindex] == "AXALIFEPRF" 
		{
#J06116			IF NUMBER(CvgFaceAmt-T[cvgindex]) >= 250000 && NUMBER(CvgInsrdRtAge[cvgindex]) >= 18
			IF NUMBER(CvgFaceAmt-T[cvgindex]) >= 500000 && NUMBER(CvgInsrdRtAge[cvgindex]) >= 18
			{
				CvgGuarLsCd-T[cvgindex] = "AXAPREF";
			}
			ELSE
			{
				CvgGuarLsCd-T[cvgindex] = "AXALIFE";
			}
		}
		IF CvgGuarLsCd-T[cvgindex] == "AXLFHYP" || CvgGuarLsCd-T[cvgindex] == "AXALIFEFLX" || CvgGuarLsCd-T[cvgindex] == "AXALIFEMAX"
		{
			CvgGuarLsCd-T[cvgindex] = "AXALIFE";
		}		
		# Get the garantee name in EDIT table
		STEP TARGET4581
		{
			USES P-STEP "BF0680-P";
			ATTRIBUTES
			{
				Explicit;
				GetMessages = "No";
			}
			"GUARLS" -> MIR-ETBL-TYP-ID;
			CvgGuarLsCd-T[cvgindex] -> MIR-ETBL-VALU-ID;
			SESSION.LSIR-USER-LANG-CD -> MIR-ETBL-LANG-CD;
			Guarantee-name <- MIR-ETBL-DESC-TXT-T[1];
		}

		# ....................    build "OLifE.Holding[1].Life.Coverage[n]" tags    ............
		IF CvgGuarType-T[cvgindex] == "COVERAGE"
		{
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].id = "Coverage_" + cvgindex;
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].ProductCode = CvgGuarLsCd-T[cvgindex];
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].PlanName = Guarantee-name;
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].CurrentAmt = RemoveLeadingZero(CvgFaceAmt-T[cvgindex]);
#J03034 Begin Ne plus afficher le Grs Prem Amt si celui-ci est >= 15000
#BLSF-201 29Sep2016 réactiver le transfert de la prime annuelle peut importe le montant.
#			IF NUMBER(PolGrsApremAmt-T[cvgindex]) >= 15000
#			{
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].TargetPremAmt = RemoveLeadingZero(PolGrsApremAmt-T[cvgindex]); 
#			}
#J03034 end
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].CovNumber = CvgCovNum-T[cvgindex];
			IF CvgInsrdClassCd-T[cvgindex] != ""
			{
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].KeyedValue.KeyName = "rateClassQuoted";
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].KeyedValue.KeyValue = CvgInsrdClassCd-T[cvgindex];
			}
			ELSE
			{
				IF CvgInsrdSmokeCd-T[cvgindex] == "S" || CvgInsrdSmokeCd-T[cvgindex] == "U"
				{
					TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].KeyedValue.KeyName = "rateClassQuoted";
					TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].KeyedValue.KeyValue = "Smoker";
				}
				IF CvgInsrdSmokeCd-T[cvgindex] == "N"				
				{
					TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].KeyedValue.KeyName = "rateClassQuoted";
					TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].KeyedValue.KeyValue = "Non smoker";
				}
			}
			CBindex = 1;
		#BLFS-201 BEGIN
			WS-BNFT-TYP-INVALID-SW = "N";
		#BLFS END
			WHILE CBindex <= CvgOption[cvgindex].CovBnfit[0]
			{
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].CovOption[CBindex].LifeCovOptTypeCode.tc = CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptTypeCode;
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].CovOption[CBindex].LifeCovOptTypeCode.Value = CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptTypeTxt;
				IF CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptAmt > 1
				{
					TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].CovOption[CBindex].OptionAmt = RemoveLeadingZero(CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptAmt);
				}
			#BLFS-201 BEGIN
			TRACE ("LiveCovOptTypeCode = : " + CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptTypeCode);
				IF CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptTypeCode == "65" || CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptTypeCode == "66" || CvgOption[cvgindex].CovBnfit[CBindex].LiveCovOptTypeCode == "68"
				{
					WS-BNFT-TYP-INVALID-SW = "Y";
				}
			#BLFS-201 END
				CBindex = CBindex + 1;
			}
		}
		TRACE ("MIR-POL-CNTCT-VIP-IND =: " + MIR-POL-CNTCT-VIP-IND);
		TRACE ("WS-BNFT-TYP-INVALID-SW =: " + WS-BNFT-TYP-INVALID-SW);
		TRACE ("CvgGuarLsCd-T[cvgindex] =: " + CvgGuarLsCd-T[cvgindex]);
		TRACE ("NUMBER(CvgFaceAmt-T[cvgindex]) =: " + NUMBER(CvgFaceAmt-T[cvgindex]));
		TRACE ("NUMBER(PolGrsApremAmt-T[cvgindex])  =: " + NUMBER(PolGrsApremAmt-T[cvgindex])) ;
		TRACE ("CvgInsrdRtAge[cvgindex] =: " + CvgInsrdRtAge[cvgindex]);
		
				#BLFS-201 begin	
		#..................................................................................................................................................................................................
		# Implémentation d'un nouvel algorithme afin d'initialiser le keyvalue du champ "Priority" à une valeur spécifique selon certains paramètres fournis par l'actuaria et l'équipe de tarificateur.
		# Les paramètres de validation sont basés sur:
		#		La tranche du capital assuré total par client et par type garantie LS.
		#		La tranche d'âge de l'assuré de la garantie
		#		avec ou sans Maladie grave (AXACI) ou avec ou sans Invalidité (Garantie complémentaire 65, 66, 68)
		#..................................................................................................................................................................................................		
		#........................... Appliquer la règle des priorités pour le produit AXACI ...............................................
		IF CvgGuarLsCd-T[cvgindex] == "AXACI"
		{
			IF NUMBER(CvgFaceAmt-T[cvgindex]) >= 500000
			{
				WS-TEMP-PRIORITY = "1";
			}
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 499999
			{
				WS-TEMP-PRIORITY = "3";
			}
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 400000
			{
				WS-TEMP-PRIORITY = "4";
			}			
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 250000
			{
				WS-TEMP-PRIORITY = "5";
			}
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 100000
			{
				WS-TEMP-PRIORITY = "6";
			}
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 50000
			{
				IF CvgInsrdRtAge[cvgindex] <= "070"
				{
					WS-TEMP-PRIORITY = "7";
				}
				ELSE
				{
					WS-TEMP-PRIORITY = "6";
				}
			}
		}
		ELSE
					#........................... Appliquer la règle des priorités pour les produits autres que AXACI ...............................................
		{
			IF NUMBER(CvgFaceAmt-T[cvgindex]) >= 5000000
			{
				WS-TEMP-PRIORITY = "1";
			}
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 4999999
			{
				WS-TEMP-PRIORITY = "3";
			}
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 2000000
			{
				WS-TEMP-PRIORITY = "4";
			}	
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 1500000
			{
				WS-TEMP-PRIORITY = "5";
			}	
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 1000000
			{
				WS-TEMP-PRIORITY = "6";
			}	
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 750000
			{
				IF CvgInsrdRtAge[cvgindex] <= "070"
				{
					WS-TEMP-PRIORITY = "7";
				}
				ELSE
				{
					WS-TEMP-PRIORITY = "6";
				}
			}
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 500000
			{
				IF CvgInsrdRtAge[cvgindex] <= "060"
				{
					IF WS-BNFT-TYP-INVALID-SW == "Y"
					{
						WS-TEMP-PRIORITY = "8";
					}
					ELSE
					{
						WS-TEMP-PRIORITY = "9";
					}
				}
				ELSE 
				{
					IF CvgInsrdRtAge[cvgindex] <= "070"
					{
						WS-TEMP-PRIORITY = "7";
					}
					ELSE
					{
						WS-TEMP-PRIORITY = "6";
					}
				}
			}				
			IF NUMBER(CvgFaceAmt-T[cvgindex]) <= 249999
			{
				IF CvgInsrdRtAge[cvgindex] <= "050"
				{
					IF WS-BNFT-TYP-INVALID-SW == "Y"
					{
						WS-TEMP-PRIORITY = "8";
					}
					ELSE
					{
						WS-TEMP-PRIORITY = "11";
					}
				}
				ELSE
				{
					IF CvgInsrdRtAge[cvgindex] <= "060"
					{
						IF WS-BNFT-TYP-INVALID-SW == "Y"
						{
							WS-TEMP-PRIORITY = "8";
						}
						ELSE
						{
							WS-TEMP-PRIORITY = "10";
						}
					}
					ELSE 
					{
						IF CvgInsrdRtAge[cvgindex] <= "070"
						{
							WS-TEMP-PRIORITY = "7";
						}
						ELSE
						{
							WS-TEMP-PRIORITY = "6";
						}
					}
				}
			}				
		}
		#*** HERE WE HAVE TO COMPARE IF THE ANNUAL PREMIUM IS GREATER THAN OR EQUAL TO $ 15 000.00. IF SO IS SENT PRIORITY 2. ***#
		IF NUMBER(PolGrsApremAmt-T[cvgindex]) >= 15000 && WS-TEMP-PRIORITY != 1
		{
			WS-TEMP-PRIORITY = "2";
		}
		# Ici on store la dernière valeur de priority stored par celle initialisée par la définition des deux algorithmes précedents.
		# Si la valeur stored est plus grande que la valeur initialisée, on store cette valeur dans le keyvalue (plus petite).
		TRACE ("WS-TEMP-PRIORITY =: " + NUMBER(WS-TEMP-PRIORITY));
		TRACE ("Policy.KeyedValue[priorityKeyIdx].KeyValue) =: " + NUMBER(TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[priorityKeyIdx].KeyValue));
#test		IF NUMBER(TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[priorityKeyIdx].KeyValue) > NUMBER(WS-TEMP-PRIORITY)
		IF NUMBER(WS-TEMP-PRIORITY) < NUMBER(TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[priorityKeyIdx].KeyValue) 
		{
			TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[priorityKeyIdx].KeyValue = WS-TEMP-PRIORITY;
		}
		TRACE ("Policy.KeyedValue[priorityKeyIdx].KeyValue) =: " + NUMBER(TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[priorityKeyIdx].KeyValue));
#BLFS-201 ENDED

		# .............  Create the Life Participant Objects   .."OLifE.Holding.Policy.Life.Coverage[n].LifeParticipant[n]"..................
		# .
		# Life Participant Objects are coverage level clients, these are insureds 
		lpindex = 1;
		# Most of the coverage information applies to the primary insured only. When index=1, we'll
		# go through a longer list of assignments. When index is 2,3,4 or 5 we'll do fewer assignments.
		#J03034  Pour le code fumeur regulier (Enfant) ont doit envoyer fumeur à LS.
		IF CvgInsrdSmokeCd-T[cvgindex] == "U"
		{
			CvgInsrdSmokeCd-T[cvgindex] = "S";
		}
		#J03034 - END
		IF cvgindex == 1
		{
		 	TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].id = "LifeParticipant_" + lpindex;
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey = CvgInsrdId-T[cvgindex];
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].ParticipantName = CvgInsrdNm-T[cvgindex];
			
			# first is always 1 primary insured, others are 2 other insured
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.Value = GetDescription("1", "LifeParticipantRoleCode");
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc = "1";
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TempFlatExtraAmt = RemoveLeadingZero(CvgFeUpremAmt-T[cvgindex]);
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TempFlatEndDate = CvgFeUpremEndDt-T[cvgindex];
			IF CvgGuarType-T[cvgindex] == "COVERAGE"
			{
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TobaccoPremiumBasis.Value = GetDescription(CvgInsrdSmokeCd-T[cvgindex], "TobaccoPremiumBasis");
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TobaccoPremiumBasis.tc = toTXLife(CvgInsrdSmokeCd-T[cvgindex], "TobaccoPremiumBasis");
			}
			# Identify the Party ID so LifeParticipant object can be matched with a Party object
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].PartyID = "Party_" + CvgInsrdId-T[cvgindex];
			IF CvgInsrdId-T[cvgindex] == OwnerId || CvgInsrdId-T[cvgindex] == SecondOwnerId
			{
				IF CvgInsrdId-T[cvgindex] == OwnerId
				{
					OwnerIsInsuredID = CvgInsrdId-T[cvgindex];
				}
				IF CvgInsrdId-T[cvgindex] == SecondOwnerId
				{
					SecondOwnerIsInsuredID = CvgInsrdId-T[cvgindex];
				}
			#	lpindex = lpindex + 1;
			#	TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.Value = GetDescription("18", "LifeParticipantRoleCode");
			#	TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc = "18";
			#	TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].PartyID = "Party_" + CvgInsrdId-T[cvgindex];
			}
			TXLifeRequest.OLifE.FormInstance.id = "Form_1";
			TXLifeRequest.OLifE.FormInstance.RelatedObjectID = "Party_" + CvgInsrdId-T[cvgindex];
			TXLifeRequest.OLifE.FormInstance.FormName = "VPI-APP-13";

 			BRANCH TARGET7311;
		}
		IF cvgindex != 1
		{
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].id = "LifeParticipant_" + lpindex;
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey = CvgInsrdId-T[cvgindex];
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].ParticipantName = CvgInsrdNm-T[cvgindex];
			# first is always 1 primary insured, others are 2 other insured
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.Value = GetDescription("2", "LifeParticipantRoleCode");
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc = "2";
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TempFlatExtraAmt = RemoveLeadingZero(CvgFeUpremAmt-T[cvgindex]);
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TempFlatEndDate = CvgFeUpremEndDt-T[cvgindex];
			TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].PartyID = "Party_" + CvgInsrdId-T[cvgindex];
			IF CvgGuarType-T[cvgindex] == "COVERAGE"
			{
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TobaccoPremiumBasis.Value = GetDescription(CvgInsrdSmokeCd-T[cvgindex], "TobaccoPremiumBasis");
				TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].TobaccoPremiumBasis.tc = toTXLife(CvgInsrdSmokeCd-T[cvgindex], "TobaccoPremiumBasis");
			}
			# Identify the Party ID so LifeParticipant object can be matched with a party object
			IF CvgInsrdId-T[cvgindex] == OwnerId || CvgInsrdId-T[cvgindex] == SecondOwnerId
			{
				IF CvgInsrdId-T[cvgindex] == OwnerId
				{
					OwnerIsInsuredID = CvgInsrdId-T[cvgindex];
				}
				IF CvgInsrdId-T[cvgindex] == SecondOwnerId
				{
					SecondOwnerIsInsuredID = CvgInsrdId-T[cvgindex];
				}
			#	lpindex = lpindex + 1;
			#	TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.Value = GetDescription("18", "LifeParticipantRoleCode");
			#	TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc = "18";
			#	TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].PartyID = "Party_" + CvgInsrdId-T[cvgindex];
			}
			index = index + 1;
			lpindex = lpindex + 1;
		}
		TARGET7311:
		cvgindex = cvgindex + 1;
	}
#BLFS-201 Une fois la priority étable selon les garanties traitées plus haut on vérifie si le paramètre VIP sur Ingenium est à OUI et que la priorité
#		  établie plus haut est 3 et plus. .
	IF MIR-POL-CNTCT-VIP-IND == "Y" && NUMBER(TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[priorityKeyIdx].KeyValue) >= 3
	{
		TXLifeRequest.OLifE.Holding[1].Policy.KeyedValue[priorityKeyIdx].KeyValue = "1";
	}
#BLSF-201 Ended.		
	# .
	# .         ...............     Create Relation and Party Objects     ..............
	# .
	# .
	# This section will find all relations for the policy and create the Relation Objects.
	# Relation Objects are created for the following relationships:
	# .	Using BF6940-P Inquiry Policy Relationships
	# .		Owner
	# .	Using BF8000 Policy Inquiry
	# .		Servicing Agent
	# .		Writing Agent
	# Use BF6940-P Inquiry - Policy Relationships to retrieve a list of clients related to the policy
	STEP TARGET4521
	{
		USES P-STEP "BF8000-P";
	}
	STEP TARGET4522
	{
		USES P-STEP "BF6940-P";
	}

	index = 1;
	relindex = 1;
	# Loop through the list of policy relations and create a Relation Object of each one.
	WHILE MIR-POL-CLI-REL-TYP-CD-T[index] != "" && index < 2
	{
	  	# Here we need to create the owner only. Skip all except Owner
		IF MIR-POL-CLI-REL-TYP-CD-T[index] != "O"
		{
			BRANCH TARGET4863;
		}

		TXLifeRequest.OLifE.Relation[relindex].id = "Relation_" + relindex;
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.tc = "4";
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.Value = "Holding";
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.tc = "6";
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.Value = "Party";
		# For Owner, we need to look at the SubType Code to find out if it's Primary or Contingent.
		# If it's Contingent, change the REL-TYP to the ACORD value for Contingent Owner "177" before
		# moving the value to the TXLife field.
#		IF MIR-POL-CLI-REL-TYP-CD-T[index] == "O" && MIR-POL-CLI-REL-SUB-CD-T[index] == "C"
#		{
#			MIR-POL-CLI-REL-TYP-CD-T[index] = "177";
#		}
		MIR-POL-CLI-INSRD-CD = MIR-POL-CLI-INSRD-CD-T[index];
		IF MIR-POL-CLI-INSRD-CD-T[index] == "SAME"
		{
			MIR-POL-CLI-INSRD-CD = "SELF";
		}
		IF MIR-POL-CLI-INSRD-CD-T[index] == ""
		{
			MIR-POL-CLI-INSRD-CD = "0";
		}
		IF MIR-POL-CLI-INSRD-CD-T[index] != "SAME" && MIR-POL-CLI-INSRD-CD-T[index] != "BRTHR" && MIR-POL-CLI-INSRD-CD-T[index] != "FATHR" && MIR-POL-CLI-INSRD-CD-T[index] != "FIANC" && MIR-POL-CLI-INSRD-CD-T[index] != "GFTHR" && MIR-POL-CLI-INSRD-CD-T[index] != "GMTHR" && MIR-POL-CLI-INSRD-CD-T[index] != "HUSBD" && MIR-POL-CLI-INSRD-CD-T[index] != "MOTHR" && MIR-POL-CLI-INSRD-CD-T[index] != "SISTR" && MIR-POL-CLI-INSRD-CD-T[index] != "WIFE"
		{
			MIR-POL-CLI-INSRD-CD = "OTHER";
		}
		TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = toTXLife(MIR-POL-CLI-REL-TYP-CD-T[index], "RelationRoleCode");
		TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = GetDescription(MIR-POL-CLI-REL-TYP-CD-T[index], "RelationRoleCode");
		TXLifeRequest.OLifE.Relation[relindex].RelationDescription.tc = toTXLife(MIR-POL-CLI-INSRD-CD, "RoleCodeDesc");
		TXLifeRequest.OLifE.Relation[relindex].RelationDescription.Value = GetDescription(MIR-POL-CLI-INSRD-CD, "RoleCodeDesc");

		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectID = TXLifeRequest.OLifE.Holding[1].id;
#		IF MIR-CLI-ID-T[index] == OwnerIsInsuredID || MIR-CLI-ID-T[index] == SecondOwnerIsInsuredID
		IF MIR-CLI-ID-T[index] == OwnerIsInsuredID 
		{
			TXLifeRequest.OLifE.Relation[relindex].RelatedObjectID = "Party_" + MIR-CLI-ID-T[index];
		}
		ELSE
		{
			TXLifeRequest.OLifE.Relation[relindex].RelatedObjectID = "Party_" + relindex;
		}
		IF MIR-POL-CLI-REL-TYP-CD-T[index] == "O" && MIR-POL-CLI-REL-SUB-CD-T[index] == "P"
		{
			TXLifeRequest.OLifE.FinancialStatement.BillingStatement.BillingDetail.OwnerPartyID = "Party_" + relindex;
			TXLifeRequest.OLifE.FinancialStatement.BillingStatement.BillingDetail.OwnerName = MIR-DV-OWN-CLI-NM-T[1];
		}
		# Save the client id and Party id for the Relation Object just created.
		# Assign Client ID to the PartyKey field so the Party Inquiry flow knows it's a Party
		# This will be used to create the associated Party Object later in the flow.

		temp.PartyCollection[relindex].id = "Party_" + relindex;
		temp.PartyCollection[relindex].CLI-ID = MIR-CLI-ID-T[index];
		temp.PartyCollection[relindex].Party[1].PartyKey = MIR-CLI-ID-T[index];
#J03034 Begin Créer une sous branche pour distinguer le OWNER.
		temp.PartyCollection[relindex].Party[1].Owner    = MIR-CLI-ID-T[index];
#J03034 end
		relindex = relindex + 1;
		TARGET4863:

		index = index + 1;
	}
	
	# Retrieve the Servicing agent on the policy
	#This condition in case that the servicing agent id is blanc on policy we will take first Writing Agent Number .
	IF MIR-SERV-AGT-ID == ""
	{
		MIR-SERV-AGT-ID = WS-SERV-AGT-ID;
	}
	IF MIR-SERV-AGT-ID != ""
	{
		TXLifeRequest.OLifE.Relation[relindex].id = "Relation_" + relindex;
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.tc = "4";
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.Value = "Holding";
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.tc = "6";
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.Value = "Party";
		# Assign relation, this agent is the servicing agent, so it's #38
		TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = toTXLife(38, "RelationRoleCode");
		TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = GetDescription(38, "RelationRoleCode");
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectID = TXLifeRequest.OLifE.Holding[1].id;
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectID = "Party_" + relindex;
		# Save the client id and Party id for the Relation Object just created.
		# Assign Client ID to the CompanyProducerID field so the Party Inquiry flow knows it's a Producer
		# This will be used to create the associated Party Object later in the flow.
		temp.PartyCollection[relindex].id = "Party_" + relindex;
		temp.PartyCollection[relindex].CLI-ID = MIR-SERV-AGT-ID;
		temp.PartyCollection[relindex].Party[1].Producer.CompanyProducerID = MIR-SERV-AGT-ID;

		# Define the Financial Statement XSM node
		TXLifeRequest.OLifE.FinancialStatement.CommissionStatement.AgentPartyID = "Party_" + relindex;
#J03034- Mettre en commentaire la condition suivante
#		IF NUMBER(BranchID) >= 40 && NUMBER(BranchID) <= 49
#		{
#			BranchID = "40";
#		}
#J03034 End.

		TXLifeRequest.OLifE.FinancialStatement.CommissionStatement.CompanyProducerID = BranchID;
		
		TXLifeRequest.OLifE.FinancialStatement.CommissionStatement.CommissionDetail.PaidProducerPartyID = "Party_" + relindex;
		AgtIdx = 1;
		WHILE AgtIdx <= 3
		{
			IF MIR-AGT-ID-T[AgtIdx] == MIR-SERV-AGT-ID
			{
				TXLifeRequest.OLifE.FinancialStatement.CommissionStatement.CommissionDetail.SplitPercent = MIR-POL-AGT-SHR-PCT-T[AgtIdx];
			}
			AgtIdx = AgtIdx + 1;
		}
		TXLifeRequest.OLifE.FinancialStatement.CommissionStatement.CommissionDetail.PaidProducerID = MIR-SERV-AGT-ID;
		index = index + 1;
		relindex = relindex + 1;
	}
#J03034 Begin - Ne plus afficher le message XS9260 0015.
#	index = 1;
#	NbrOfWrtgnAgt = 0;
#	WHILE MIR-AGT-ID-T[index] != ""
#	{
#		NbrOfWrtgnAgt = NbrOfWrtgnAgt + 1;
#		index = index + 1;
#	}
#	IF NbrOfWrtgnAgt > 1
#	{
#		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
#		{
#			MsgsIdx = MsgsIdx + 1;
#		}
#		#More than 1 advisor on the policy.   
#		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600015";
#	}
#J03034 end
	#	For Life Suite we don't want to send all agent id in the table. The Servicing agent ID only is necessary. 
#	So we will bypass the next step by the instruction 'BRANCH TARGET4865'
	BRANCH TARGET4865;
	# Retrieve the agents on the policy
	index = 1;
	WHILE MIR-AGT-ID-T[index] != ""
	{
		TXLifeRequest.OLifE.Relation[relindex].id = "Relation_" + relindex;
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.tc = "4";
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.Value = "Holding";
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.tc = "6";
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.Value = "Party";
		# Assign relation, this agent is the writing agent, so it's #37
		TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = toTXLife("37", "RelationRoleCode");
		TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = GetDescription("37", "RelationRoleCode");
		TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectID = TXLifeRequest.OLifE.Holding[1].id;
		TXLifeRequest.OLifE.Relation[relindex].RelatedObjectID = "Party_" + relindex;
		TXLifeRequest.OLifE.Relation[relindex].InterestPercent = MIR-POL-AGT-SHR-PCT-T[index];
		# Save the client id and Party id for the Relation Object just created.
		# Assign Client ID to the CompanyProducerID field so the Party Inquiry flow knows it's a Producer
		# This will be used to create the associated Party Object later in the flow.
		temp.PartyCollection[relindex].id = "Party_" + relindex;
		temp.PartyCollection[relindex].Party[1].Producer.CompanyProducerID = MIR-AGT-ID-T[index];
		temp.PartyCollection[relindex].CLI-ID = MIR-AGT-ID-T[index];
		index = index + 1;
		relindex = relindex + 1;
	}

	TARGET4865:
	# Create the Carrier relation here if it's required.
	# .
	# .
	# Create Relations for Life Participants.
	# Loop through Life Participant and Participant and create the Relation and Party Objects
	# Initialize coverage record counter and LifeParticipantcounter.
	# Save the number of Relations created up to this point. This will tell use the starting point
	# for Relations created for Life Participant or Participant Objects.
	cvgindex = 1;
	start-relindex = relindex;
	relparty = relindex;
	lpindex = 1;
	# Loop as long as we have Life Participant records
	WHILE cvgindex <= TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[0]
	{
		lpindex = 1;
		WHILE lpindex <= TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[0]
		{
			index = start-relindex;
			# Loop through all Relations created for a Participants and see one was already created
			# for this client. Start on Relation number start-relindex.
			WHILE temp.PartyCollection[index].CLI-ID != ""
			{
				IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey == temp.PartyCollection[index].CLI-ID
				{
					BRANCH TARGET5432;
				}
				index = index + 1;
			}
			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc == "18"
			{
				BRANCH TARGET5432;
			}
			TXLifeRequest.OLifE.Relation[relindex].id = "Relation_" + relindex;
			TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.tc = "4";
			TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.Value = "Holding";
			TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.tc = "6";
			TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.Value = "Party";
			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc == "1"
			{
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = "96";
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = GetDescription("96", "RelationRoleCode");
			}
			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc == "2"
			{
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = "96";
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = GetDescription("96", "RelationRoleCode");
			}
			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc == "7"
			{
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = "34";
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = GetDescription("34", "RelationRoleCode");
			}
			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc == "9"
			{
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = "36";
				TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = GetDescription("36", "RelationRoleCode");
			}
			TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectID = TXLifeRequest.OLifE.Holding[1].id;
			TXLifeRequest.OLifE.Relation[relindex].RelatedObjectID = "Party_" + TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey;

			# Save the client id and Party id for the Relation Object just created.
			# Assign Client ID to the PartyKey field so the Party Inquiry flow knows it's a Party
			# This will be used to create the associated Party Object later in the flow.
			# IF the Participant Key field is blank, we can create the Party Object Here

			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey != ""
			{
				temp.PartyCollection[relparty].id = "Party_" + TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey;
				temp.PartyCollection[relparty].CLI-ID = TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey;
				temp.PartyCollection[relparty].Party[1].PartyKey = TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey;
			}

			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey == ""
			{
				temp.PartyCollection[relparty].id = TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].PartyID;
				temp.PartyCollection[relparty].CLI-ID = "";
				TXLifeRequest.OLifE.Party[relindex].FullName = TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].ParticipantName;
				TXLifeRequest.OLifE.Party[relindex].id = temp.PartyCollection[relindex].id;
				TXLifeRequest.OLifE.Relation[relindex].RelatedObjectID = temp.PartyCollection[relindex].id;
			}
			# Here want to create XML NODE if other Insurance existing for this insured
			IF TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc == "1" || TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantRoleCode.tc == "2"
			{
				STEP TARGET9846
				{
					USES P-STEP "BF0550-P";
					temp.PartyCollection[index].CLI-ID -> MIR-CLI-ID;
				}
				IF MIR-OINS-INFC-PEND-IND == "Y" && MIR-CLI-OINS-CO-NM-T[0] > 0
				{
					OIindex = 1;
					WHILE MIR-CLI-OINS-CO-NM-T[OIindex] != ""
					{
						relindex = relindex + 1;
						INDX = INDX + 1;
						TXLifeRequest.OLifE.Relation[relindex].id = "Relation_" + relindex;
						TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectID = "Party_" + TXLifeRequest.OLifE.Holding[1].Policy.Life.Coverage[cvgindex].LifeParticipant[lpindex].LifeParticipantKey;
						TXLifeRequest.OLifE.Relation[relindex].RelatedObjectID = "Holding_" + INDX;
						TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.tc = "6";
						TXLifeRequest.OLifE.Relation[relindex].OriginatingObjectType.Value = "Party";
						TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.tc = "4";
						TXLifeRequest.OLifE.Relation[relindex].RelatedObjectType.Value = "Holding";
						TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.tc = "2147483647";
						TXLifeRequest.OLifE.Relation[relindex].RelationRoleCode.Value = "Other Insurance";
						# Create holding for all other Insurance for this party_insured
						TXLifeRequest.OLifE.Holding[INDX].id = "Holding_" + INDX;
						TXLifeRequest.OLifE.Holding[INDX].HoldingStatus.tc = "1"; 
						TXLifeRequest.OLifE.Holding[INDX].HoldingStatus.Value = "Active";
						TXLifeRequest.OLifE.Holding[INDX].Policy.CarrierCode = MIR-CLI-OINS-CO-NM-T[OIindex];
						TXLifeRequest.OLifE.Holding[INDX].Policy.PolicyValue = RemoveLeadingZero(MIR-CLI-OINS-TOT-AMT-T[OIindex]);
						TXLifeRequest.OLifE.Holding[INDX].Policy.KeyedValue.KeyName = "Status";
						STEP TARGET9847
						{
							USES P-STEP "BF8100-P";
							"OINS-INFC-PEND-CD" -> MIR-DM-AV-TBL-CD;
							MIR-OINS-INFC-PEND-CD-T[OIindex] -> MIR-DM-AV-CD;
							SESSION.LSIR-USER-LANG-CD -> MIR-DM-AV-DESC-LANG-CD;
							"E" -> MIR-DM-AV-DESC-LANG-CD;
						}
						IF MIR-OINS-INFC-PEND-CD-T[OIindex] == ""
						{
							TXLifeRequest.OLifE.Holding[INDX].Policy.KeyedValue.KeyValue = "Not in-force";
						}
						ELSE
						{
							TXLifeRequest.OLifE.Holding[INDX].Policy.KeyedValue.KeyValue = MIR-DM-AV-DESC-TXT;
						}
						OIindex = OIindex + 1;
					}
				}
			}
			relparty = relparty + 1;
			relindex = relindex + 1;
			TARGET5432:
			lpindex = lpindex + 1;
		}
		cvgindex = cvgindex + 1;
	}

	#********************************************************************************************************************************
	#******** Call the TC204Handle_LifeSuite in order to build all personnal information of each participant of the policy **********
	#********************************************************************************************************************************	
	index = 1;
	i = 1;
	SIN-i = 1;
	WHILE i <= 100
	{
		wsGovtID-T[i] = "";
		wsPartyKey-T[i] = "";
		i = i + 1;
	}
	WHILE index <= temp.PartyCollection[0]
	{
		IF temp.PartyCollection[index].CLI-ID != "" &&  temp.PartyCollection[index].CLI-ID != "BypassThisParty"
		{
			partyrequest = TXLifeRequest;

			# Use the TC204 Client Inquiry Handler flow to create the Required Party Object
			# Build the request required for the Client Inquiry Handler, this includes: InquiryLevel and Client ID.
			partyrequest.InquiryLevel = "1";
			partyrequest.OLifE.Party[1] = temp.PartyCollection[index].Party[1];
			partyrequest.TransResult = partyresponse.TransResult;
			partyrequest = partyrequest;
			STEP TARGET3522
			{
				USES PROCESS "TC204Handler_LifeSuite";
				partyrequest -> request;
				partyresponse <- response;
			}

			# Transform XML response back to structured data
			# Assign the new Party Object to the appropriate location in the Response Object
			# Assign the Party ID in the object so we can identify it.
			
			partyresponse = partyresponse;
			IF partyresponse.OLifE.Party[1].GovtID == "000000000" || DoesExist(partyrequest.OLifE.Party[1].Producer.CompanyProducerID) == "true"
			{
				BRANCH TARGET9001;
			}
			i = 1;
			WHILE (i < SIN-i)
			{
				IF (wsGovtID-T[i] == partyresponse.OLifE.Party[1].GovtID && wsPartyKey-T[i] != partyresponse.OLifE.Party[1].PartyKey)
				{
					WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != "" 
					{
						MsgsIdx = MsgsIdx + 1;
					}
					#More than one participant have the same Social Identification Number (SIN). 
					MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600016";
					MIR-MSG-PARM-INFO-1-T[MsgsIdx] = wsPartyKey-T[i];
					MIR-MSG-PARM-INFO-2-T[MsgsIdx] = partyresponse.OLifE.Party[1].PartyKey;
					WS-PARTY-ERROR = "5";
				#	BRANCH WriteUserMessage;
				}
				i = i + 1;
			}
			wsGovtID-T[SIN-i] = partyresponse.OLifE.Party[1].GovtID;
			wsPartyKey-T[SIN-i] = partyresponse.OLifE.Party[1].PartyKey;
			SIN-i = SIN-i + 1;
			TARGET9001:
			TXLifeRequest.OLifE.Party[index] = partyresponse.OLifE.Party[1];
			TXLifeRequest.OLifE.Party[index].id = temp.PartyCollection[index].id;
			
			# The Result Code from the subflow should be used to update the Result Code
			# in this flow. Since this isn't the main part of transaction, a failure should
			# only be recorded with a "2" error code and should not replace an existing "5".
			IF partyresponse.TransResult.ResultCode.tc == "5"
			{
				WS-PARTY-ERROR = "5";
			}
#			IF partyresponse.TransResult.ResultCode.tc == "5"
#			{
#				WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
#				{
#					MsgsIdx = MsgsIdx + 1;
#				}
#				msgindex = 1;
#				WHILE (partyresponse.TransResult.ResultInfo[msgindex].ResultInfoDesc != "")
#				{
#					IF partyresponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc == "200"
#					{
#						# A failure error has been found on one participant @1 - @2.
#						MIR-MSG-REF-INFO-T[MsgsIdx] = partyresponse.TransResult.ResultInfo[msgindex].ResultInfoDesc;
#						MIR-MSG-PARM-INFO-1-T[MsgsIdx] = partyresponse.OLifE.Party[1].PartyKey;
#						msgindex = msgindex + 1;
#						MsgsIdx = MsgsIdx + 1;
#					}
#					ELSE
#					{
#						#An error has been found on one of the participants @1 - @2 - @3.     
#						MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600008";
#						MIR-MSG-PARM-INFO-1-T [MsgsIdx] = TXLifeRequest.OLifE.Party[index].id;
#						MIR-MSG-PARM-INFO-2-T[MsgsIdx] = partyresponse.OLifE.Party[1].PartyKey;
#						MIR-MSG-PARM-INFO-3-T[MsgsIdx] = partyresponse.TransResult.ResultInfo[msgindex].ResultInfoDesc;
#						MsgsIdx = MsgsIdx + 1;
#						msgindex = msgindex + 1;
#					}
#				}
#				BRANCH WriteUserMessage;
#			}
		}
		index = index + 1;
	}
#J03034 Begin If some errors occurs on the one or more participant process errors
	# The Result Code from the subflow should be used to update the Result Code
	# in this flow. Since this isn't the main part of transaction, a failure should
	# only be recorded with a "2" error code and should not replace an existing "5".
#	IF partyresponse.TransResult.ResultCode.tc == "5"
	IF WS-PARTY-ERROR == "5"
	{
#		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
#		{
#			MsgsIdx = MsgsIdx + 1;
#		}
		MsgsIdx = 1;
		msgindex = 1;
		WHILE (partyresponse.TransResult.ResultInfo[msgindex].ResultInfoDesc != "")
		{
			IF partyresponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc == "200"
			{
				# A failure error has been found on one participant @1 - @2.
				MIR-MSG-REF-INFO-T[MsgsIdx] = partyresponse.TransResult.ResultInfo[msgindex].ResultInfoDesc;
#				MIR-MSG-PARM-INFO-1-T[MsgsIdx] = partyresponse.OLifE.Party[1].PartyKey;
				MIR-MSG-PARM-INFO-1-T[MsgsIdx] = partyresponse.TransResult.ResultInfo[msgindex].Party_Key;
				IF DoesExist(partyresponse.TransResult.ResultInfo[msgindex].ResultInfoParm2) == "true"
				{
					MIR-MSG-PARM-INFO-2-T[MsgsIdx] = partyresponse.TransResult.ResultInfo[msgindex].ResultInfoParm2;
				}
					IF DoesExist(partyresponse.TransResult.ResultInfo[msgindex].ResultInfoParm3) == "true"
				{
					MIR-MSG-PARM-INFO-3-T[MsgsIdx] = partyresponse.TransResult.ResultInfo[msgindex].ResultInfoParm3;
				}
				msgindex = msgindex + 1;
				MsgsIdx = MsgsIdx + 1;
			}
			ELSE
			{
				#An error has been found on one of the participants @1 - @2 - @3.     
				MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600008";
#				MIR-MSG-PARM-INFO-1-T [MsgsIdx] = TXLifeRequest.OLifE.Party[index].id;
#				MIR-MSG-PARM-INFO-2-T[MsgsIdx] = partyresponse.OLifE.Party[1].PartyKey;
				MIR-MSG-PARM-INFO-1-T[MsgsIdx] = partyresponse.TransResult.ResultInfo[msgindex].Party_Key;
				MIR-MSG-PARM-INFO-2-T[MsgsIdx] = SUBSTRING(partyresponse.TransResult.ResultInfo[msgindex].ResultInfoDesc, 1, 40);
				MsgsIdx = MsgsIdx + 1;
				msgindex = msgindex + 1;
			}
		}
		BRANCH WriteUserMessage;
	}
#J03034 Endded

	# Converts the request structured data entity to XML.
	TXLife.TXLifeRequest = TXLifeRequest;
	Root.TXLife = TXLife;
	request = toXMLgeneric(Root, "TXLife");
#	TRACE("request after generic = : " + request);
	request = TRANSFORM(request, "XMLifeRequests_LifeSuite.xsl");
	
	TRACE(" XML Request to transfer after TRANSFORM = :" + request);
#	WriteFileInFolder("////ssq409//D$//i660//pr//presentation//logs//", WS-POL-ID, request, "_TXLifeRequest.xsl");
	WriteFileInFolder("////ssq408//i660//st//presentation//logs//", WS-POL-ID, request, "_TXLifeRequest.xsl");
#	BRANCH WriteUserMessage;
	
	# Send the transformed XML into Life Suite
#	TRACE("Before Call P-STEP TC103IngToLSuite-P for URL http://ssq257/MessageExchange/ElinksMessageService.asmx?wsdl Interface with Life Suite ");
	
	request.message = request;
	STEP SendToLifeSuite
	{
		USES P-STEP "TC103IngToLSuite-P";
		request -> message;
		MIR-DV-LS-INTRFCE-RSPSE <- ProcessRequestResult;
	}
	
	MIR-DV-LS-INTRFCE-RSPSE = TRANSFORM(MIR-DV-LS-INTRFCE-RSPSE, "XMLifeResponses.xsl");
	TXLifeResponse = fromTXLifeXML(MIR-DV-LS-INTRFCE-RSPSE);
	
#	TRACE ("TXLifeResponse after TRANSFORM and fromTXLifeXML =: " + TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode.tc);
#	TRACE ("TXLifeResponse after TRANSFORM and fromTXLifeXML =: " + TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultInfo.ResultInfoDesc);

#	Lifesuite9, le retour de LifeSuite a changé par rapport à celui de la version 5.5 
#	IF TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode == "SUCCESS" 
#	WriteFileInFolder("////ssq409//D$//i660//pr//presentation//logs//", WS-POL-ID, MIR-DV-LS-INTRFCE-RSPSE, "_TXLifeResponse.xsl");
	WriteFileInFolder("////ssq408//i660//st//presentation//logs//", WS-POL-ID, MIR-DV-LS-INTRFCE-RSPSE, "_TXLifeResponse.xsl");
# 
 	TRACE("After TC103IngToLSuite-P P-STEP'S CALL "  + MIR-DV-LS-INTRFCE-RSPSE);
 	TRACE("TXLifeResponse "  + WS-POL-ID + " : " +  TXLifeResponse);

 IF TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode.tc == "2" || TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode.tc == "1"
	{
		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
		{
			MsgsIdx = MsgsIdx + 1;
		}
		#msg: The contract was received by LifeSuite successfully.       
		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600006";
		IF SESSION.LSIR-USER-LANG-CD == "F"
		{
			TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode = "Reçu avec succès";
		}
		ELSE
		{
			TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode = "Successfully received";
		}
		MIR-DV-LS-INTRFCE-RSPSE  =  TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode;
#I125348 Refaire la lecture de la police avant le rappel du P-STEP AppBF8002-P pour la mise la jour de la date du transfert lifesuite afin de ne pas écraser 
#        ou modifer des données d'origine sur la police. 
		STEP callbackContractRetrieve
		{
			USES P-STEP "BF8000-P";
			ATTRIBUTES
			{
				GetMessages = "Merge";
			}
		}
#I125348 ended	
		STEP ApplicationAnalysisPolicyUpdate
		{
			USES P-STEP "AppBF8002-P";
			ATTRIBUTES
			{
				GetMessages = "Yes";
			}
			SESSION.LSIR-SYS-DT-EXT -> MIR-POL-PREV-TRNFR-LS-DT;
			SESSION.MIR-USER-ID -> MIR-USER-ID;
			
		}
	}
	ELSE
	{
#		WHILE MIR-MSG-REF-INFO-T[MsgsIdx] != ""
#		{
#			MsgsIdx = MsgsIdx + 1;
#		}
		#msg: The contract was received by LifeSuite without success.       
		MsgsIdx = 1;
		MIR-MSG-REF-INFO-T[MsgsIdx] = "XS92600007";
		MIR-DV-LS-INTRFCE-RSPSE  =  TXLifeResponse.TXLife.TXLifeResponse.TransResult.ResultCode + ": " +  SUBSTRING(MIR-DV-LS-INTRFCE-RSPSE,1,2000);
#J06082 begin change - CALL GDA CREATION.
		WS-LS-CALLBACK-ERROR = "Y";
#J06082 END OF CHANGE	
	}

	#------------------------------------------------------------------------------------------#
	# Call CSOM9260 to retrieve all errors and info messages detected during process.   #
	# All messages will be added in MSIN table and send at screen as well.                 #
	#------------------------------------------------------------------------------------------#
	STEP WriteUserMessage
	{
		USES P-STEP "BF9261-P";
		WS-POL-ID -> MIR-POL-OR-CLI-ID;
		"P" -> MIR-POL-OR-CLI-CD;
		"LSUITE01" -> MIR-USER-ID;
#		MIR-DV-LS-TRGR-MSG <- MIR-MSG-TXT-INFO-T[1];
	}
	index = 1;
	WHILE MIR-MSG-TXT-INFO-T[index] != ""
	{
		MIR-DV-LS-TRGR-MSG-T[index] = MIR-MSG-TXT-INFO-T[index];
		index = index +1;
	}
#J06082 begin change - CALL GDA CREATION.
TRACE ("USER ID : " + SESSION.MIR-USER-ID );
	IF ((WS-PARTY-ERROR == 5 || WS-DV-TRGR-SW == "OFF" || WS-LS-CALLBACK-ERROR == "Y") && SESSION.MIR-USER-ID == "TALEND")
	{
		STEP CreationFDT
		{
			USES P-STEP "BF9301-P";
			ATTRIBUTES
			{
				GetMessages = "Yes";
			}
			WS-POL-ID -> MIR-POL-ID-BASE;
			"NV98" -> MIR-ACTV-TYP-CD;
			SESSION.LSIR-SYS-DT-EXT -> MIR-ACTV-EFF-DT;
			"EAP" -> MIR-COMM-CD;
			"ISS" -> MIR-SERV-CD;
		}
	}
#J06082 END OF CHANGE	
	# Send the request response from Life Suite into the screen + All the messages incurred.
	STEP OutputData
	{
		USES S-STEP "TC103IngToLSuite-O";
		"ButtonBarOK" -> ButtonBar;
		STRINGTABLE.IDS_TITLE_LifeSuiteInterfaceOutput -> Title;

	}
	IF action == "ACTION_BACK" || action == "ACTION_OK"
	{
		EXIT;
	}
	ELSE
	{
		EXIT;
	}
}


























	