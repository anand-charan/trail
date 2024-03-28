#<HEADER>
#<DESCRIPTION>
#Party Inquiry Transaction TC=204
#</DESCRIPTION>
#<COPYRIGHT>
#© 2004 INSURANCE SOFTWARE SOLUTIONS CORP.  ALL RIGHTS RESERVED
#</COPYRIGHT>
#<HISTORY>
#<COMMENT>
#**********************************************************************************************
#* Mandat Date      Auth. Description 
#*
#* IN003  03MAR2008 JFO   Retrieve the request informations on each party included on contract
#*                        to complete the TC103 transaction.
#* DDC628 02Sep2010 JFO   Retrieve MIR-ENTR-SUR-NM-2 instead MIR-ENTR-SUR-NM-T[1] 
#  IN003  06Dec2011 JFO   Faire des validations sur certaines info de l'assuré
#                         concernant le MIB.
#  J03034 18Feb2013 JFO   remettre la valeur champ "MIR-ENTR-SUR-NM-T[1]" au transfert.
#  J03230 30Apr2013 JFO   Valider standard numéro téléphone lors du transfert vers LifeSuite.
#  J06147 13Nov2019 JFO   Réactiver le MiddleName de l'assuré vers le XML 
#**********************************************************************************************
#</COMMENT>
#</HISTORY>
#</HEADER>
# .
# .
# .          This transaction will inquire on a party  record.
# .          Inquiry is done one record at a time, the request needs to include one of the following:
# .          The client id in the PartyKey field
# .          The agent id in the CompanyProducerID field
# .          The company id in the CarrierCode field
# .
PROCESS TC204Handler_LifeSuite
{
	VARIABLES
	{
		# This input variable contains an individual request in XML format.
		IN request;
		# This output variable contains an individual response in XML format.
		OUT response;

	}
	KeyIdx = 0;
	# Convert the composite TxLife request to structured data using the function "fromXML".
	TxLifeRequest = request;
	# Initialize the result code to "1" for success. If an error is encountered, the code will be changed to an error value.
	TxLifeResponse.TransResult = TxLifeRequest.TransResult;
	TxLifeResponse.TransResult.ResultCode.tc = "1";
	LSIR-RETURN-CD = "00";
	IF SESSION.LSIR-USER-LANG-CD == "E"
	{
		WS-OWNER = "Owner";
		WS-INSRD = "Insured";
		WS-HO = "Residence";
		WS-CP = "Cellular";
		WS-BU = "Business";
	}
	ELSE
	{
		WS-OWNER = "Propriétaire";
		WS-HO = "domicile";
		WS-CP = "cellulaire";
		WS-BU = "entreprise";
		WS-INSRD = "Assuré";
	}
	# .
	# .
	# .          ................     Assign values for the input key     ...............
	# .
	# .
	# Initialize variables used in the flow
	msgindex = 1;
	WHILE TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc != ""
	{
		msgindex = msgindex + 1;
	}
	MIR-CLI-ID = TxLifeRequest.OLifE.Party[1].PartyKey;
	# .
	# .
	# .        ..........     Create information for Party records     ..........
	# .
	# .
	# Check what type of id was sent. If it's PartyKey, inquire on party information
	IF DoesExist(TxLifeRequest.OLifE.Party[1].PartyKey) == "true"
	{
		# Use BF1220 Client Inquiry to retrieve the client information.
		STEP TARGET2326
		{
			USES P-STEP "BF1220-P";
			"N" -> MIR-CHCK-CLI-CNFD-IND;
		}
#		TRACE("LSIR-RETURN-CD BF1220-P  Debut du flow = "  + LSIR-RETURN-CD);

		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03" && LSIR-RETURN-CD != "05"
		{
			# The retrieve didn't work.
			# Assign the error value "5" to the result code and branch to the end of the flow.
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			index = 1;
			WHILE MESSAGES-T[index] != ""
			{
				IF MessageSeverity(MESSAGES-T[index]) > 2
				{
					IF SESSION.LSIR-USER-LANG-CD == "E"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Client not found: " + MESSAGES-T[index];
					}
					ELSE
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Client inexistant: " + MESSAGES-T[index];
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
					msgindex = msgindex + 1;
				}

				index = index + 1;
			}
			BRANCH TARGET7643;
		}

		# .
		# .
		# . 		..........	Assign INGENIUM values to ACORD  fields	..........
		# .
		# .
		# .
		# .
		# . 		..........      NAME section of Client Update ..............
		# .
#		TxLifeResponse.OLifE.Party[1].PartyTypeCode.tc = toTXLife(MIR-CLI-SEX-CD, "PartyTypeCode");
#		TxLifeResponse.OLifE.Party[1].PartyTypeCode.Value = GetDescription(MIR-CLI-SEX-CD, "PartyTypeCode");
		TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
		# If the party is a company, only a couple of the client fields needs to be assigned
		IF MIR-CLI-SEX-CD == "C"
		{
#			CompanyName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 11, 50) + " " + SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, 10);
#			TxLifeResponse.OLifE.Party[1].FullName = CompanyName;
			TxLifeResponse.OLifE.Party[1].FullName = MIR-CLI-CO-ENTR-NM-T[1];
			TxLifeResponse.OLifE.Party[1].GovtID = MIR-CLI-TAX-ID;
			TxLifeResponse.OLifE.Party[1].GovIDTC.tc = toTXLife("2", "GovIDTC");
			TxLifeResponse.OLifE.Party[1].GovIDTC.Value = GetDescription("2", "GovIDTC");
			IF MIR-CLI-CHRTY-IND == "Y"
			{
				MIR-CLI-SEX-CD = "T";
			}
#			TxLifeResponse.OLifE.Party[1].Organization.OrgForm.tc = toTXLife(MIR-CLI-SEX-CD, "OrgFormTC");
#			TxLifeResponse.OLifE.Party[1].Organization.OrgForm.Value = GetDescription(MIR-CLI-SEX-CD, "OrgFormTC");
			TxLifeResponse.OLifE.Party[1].Organization.TrustType.tc = toTXLife(MIR-CLI-SEX-CD, "OrgFormTC");
			TxLifeResponse.OLifE.Party[1].Organization.TrustType.Value = GetDescription(MIR-CLI-SEX-CD, "OrgFormTC");
			IF NUMBER(SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, 1)) >= 0 && NUMBER(SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, 1)) <= 9
			{
				TxLifeResponse.OLifE.Party[1].Person.FirstName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, 10);			
				TxLifeResponse.OLifE.Party[1].Person.LastName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 11, 50);			
			}
			IF MIR-CLI-ID != ""
			{
				KeyIdx = KeyIdx + 1;
				TxLifeResponse.OLifE.Party[1].KeyedValue[KeyIdx].KeyName = "CLIENTID";
				TxLifeResponse.OLifE.Party[1].KeyedValue[KeyIdx].KeyValue = MIR-CLI-ID;
			}	
			# Skip over the rest of the assignment statements for the client information.
			BRANCH TARGET5224;
		}
		IF MIR-ENTR-GIV-NM-T[1] == ""
		{
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600018";
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
			msgindex = msgindex + 1;
		}
#		TxLifeResponse.OLifE.Party[1].Person.Title = MIR-CLI-INDV-TITL-TXT-T[1];
		TxLifeResponse.OLifE.Party[1].Person.FirstName = MIR-ENTR-GIV-NM-T[1];
#J06147 - Reactive the MiddleName
		TxLifeResponse.OLifE.Party[1].Person.MiddleName = MIR-CLI-INDV-MID-NM-T[1];
		TxLifeResponse.OLifE.Party[1].Person.LastName = MIR-ENTR-SUR-NM-T[1];
#J03034		TxLifeResponse.OLifE.Party[1].Person.LastName = MIR-ENTR-SUR-NM-2;
		TxLifeResponse.OLifE.Party[1].Person.Suffix = MIR-CLI-INDV-SFX-NM-T[1];
	# begin of modif 05Mar2008  --> Add Last Name at Birth and use tag KeyedValue for that ???
		IF MIR-ENTR-BTH-SUR-NM != ""
		{
			KeyIdx = KeyIdx + 1;
			TxLifeResponse.OLifE.Party[1].KeyedValue[KeyIdx].KeyName = "applicantBirthName";
			TxLifeResponse.OLifE.Party[1].KeyedValue[KeyIdx].KeyValue = MIR-ENTR-BTH-SUR-NM;
		}
		IF MIR-CLI-ID != ""
		{
			KeyIdx = KeyIdx + 1;
			TxLifeResponse.OLifE.Party[1].KeyedValue[KeyIdx].KeyName = "CLIENTID";
			TxLifeResponse.OLifE.Party[1].KeyedValue[KeyIdx].KeyValue = MIR-CLI-ID;
		}	
	# End of modif 05Mar2008
		# .
		# . 		..........      PROFILE section of Client Update ..............
		# .
		# Get the Jurisdiction of birth in Translation Table (TTAB) table

		#J03034 - Bypass the Jurisdiction of birth if the client in current process is OWNER
		IF DoesExist(TxLifeRequest.OLifE.Party[1].Owner) == "true"
		{
			BRANCH TARGET5223;
		}
		#J03034 End
		IF MIR-CLI-BTH-LOC-CD == "" 
		{
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600019";
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
			msgindex = msgindex + 1;
			BRANCH TARGET5223;
		}
		STEP TARGET5230
		{
			USES P-STEP "BF0290-P";
			"TCODE" -> MIR-ETBL-TYP-ID;
			MIR-CLI-BTH-LOC-CD -> MIR-ETBL-VALU-ID;
			"INGENIUM" -> MIR-TTBL-SYS-ID;
		}
#		TRACE("LSIR-RETURN-CD BF0290-P = "  + LSIR-RETURN-CD);
		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03" && LSIR-RETURN-CD != "05"
		{
			# The Address retrieve didn't work.
			# Assign the error value "5" to the result code since this isn't the primary transaction.
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			index = 1;
			WHILE MESSAGES-T[index] != ""
			{
				IF MessageSeverity(MESSAGES-T[index]) > 2
				{
					IF SESSION.LSIR-USER-LANG-CD == "E"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Jurisdiction of birth: " + MESSAGES-T[index];
					}
					ELSE
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Lieu de naissance: " + MESSAGES-T[index];
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
					msgindex = msgindex + 1;
				}

				index = index + 1;
			}

#			# Branch to next section.
# 			BRANCH TARGET5223;
		}
		LSIR-RETURN-CD = "00"; 
		IF MIR-TTBL-VALU-TXT-T[1] != ""
		{
			IF MIR-TTBL-VALU-TXT-T[1] == "K"
			{
				TxLifeResponse.OLifE.Party[1].Person.BirthCountry.Value = GetDescription("CANADA", "BirthCountry");
				TxLifeResponse.OLifE.Party[1].Person.BirthCountry.tc = toTXLife("CANADA", "BirthCountry");
			}
			ELSE
			{
				TxLifeResponse.OLifE.Party[1].Person.BirthCountry.Value = GetDescription("US", "BirthCountry");
				TxLifeResponse.OLifE.Party[1].Person.BirthCountry.tc = toTXLife("US", "BirthCountry");
			}
			TxLifeResponse.OLifE.Party[1].Person.BirthJurisdictionTC.Value = GetDescription(MIR-CLI-BTH-LOC-CD, "BirthJurisdictionTC");
			TxLifeResponse.OLifE.Party[1].Person.BirthJurisdictionTC.tc = toTXLife(MIR-CLI-BTH-LOC-CD, "BirthJurisdictionTC");	
		}	
		ELSE
		{
			TxLifeResponse.OLifE.Party[1].Person.BirthCountry.Value = GetDescription(MIR-CLI-BTH-LOC-CD, "BirthCountry");
			TxLifeResponse.OLifE.Party[1].Person.BirthCountry.tc = toTXLife(MIR-CLI-BTH-LOC-CD, "BirthCountry");
		}
		
		TARGET5223:
		IF MIR-CLI-BTH-DT == ""
		{
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600017";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
			msgindex = msgindex + 1;
		}
		TxLifeResponse.OLifE.Party[1].Person.BirthDate = MIR-CLI-BTH-DT;
		IF MIR-CLI-CTZN-CTRY-CD != ""
		{
			TxLifeResponse.OLifE.Party[1].Person.Citizenship.Value = GetDescription(MIR-CLI-CTZN-CTRY-CD, "CountryTC");
			TxLifeResponse.OLifE.Party[1].Person.Citizenship.tc = toTXLife(MIR-CLI-CTZN-CTRY-CD, "CountryTC");
		}
		IF MIR-CLI-SEX-CD != ""
		{
			TxLifeResponse.OLifE.Party[1].Person.Gender.Value = GetDescription(MIR-CLI-SEX-CD, "Gender");
			TxLifeResponse.OLifE.Party[1].Person.Gender.tc = toTXLife(MIR-CLI-SEX-CD, "Gender");
		}
		IF MIR-CLI-SMKR-CD != ""
		{
			TxLifeResponse.OLifE.Party[1].Person.SmokerStat.Value = GetDescription(MIR-CLI-SMKR-CD, "SmokerStat");
			TxLifeResponse.OLifE.Party[1].Person.SmokerStat.tc = toTXLife(MIR-CLI-SMKR-CD, "SmokerStat");
		}
		TxLifeResponse.OLifE.Party[1].GovtID = MIR-CLI-TAX-ID;
		TxLifeResponse.OLifE.Party[1].GovIDTC.tc = toTXLife("3", "GovIDTC");
		TxLifeResponse.OLifE.Party[1].GovIDTC.Value = GetDescription("3", "GovIDTC");
		IF MIR-CLI-MARIT-STAT-CD != ""
		{
			TxLifeResponse.OLifE.Party[1].Person.MarStat.Value = GetDescription(MIR-CLI-MARIT-STAT-CD, "MarStat");
			TxLifeResponse.OLifE.Party[1].Person.MarStat.tc = toTXLife(MIR-CLI-MARIT-STAT-CD, "MarStat");
		}
		# .
		# . 		...........  ADDRESS section of Client Update ..............
		# .
		IF MIR-CLI-CRNT-LOC-CD-1 != "" && MIR-CLI-CRNT-LOC-CD-1 != "XX"
		{
			TxLifeResponse.OLifE.Party[1].ResidenceState.Value = GetDescription(MIR-CLI-CRNT-LOC-CD-1, "StateTC");
			TxLifeResponse.OLifE.Party[1].ResidenceState.tc = toTXLife(MIR-CLI-CRNT-LOC-CD-1, "StateTC");
		}
		TxLifeResponse.OLifE.Party[1].ResidenceCountry.Value = GetDescription(MIR-CLI-CTRY-CD-1, "CountryTC");
		TxLifeResponse.OLifE.Party[1].ResidenceCountry.tc = toTXLife(MIR-CLI-CTRY-CD-1, "CountryTC");
		TxLifeResponse.OLifE.Party[1].ResidenceZip = MIR-CLI-PSTL-CD-1;
		TxLifeResponse.OLifE.Party[1].ResidenceCounty = MIR-CLI-ADDR-CNTY-CD-T[1];
		
		#J03034 - Bypass EMPLOYMENT section of Client Update if the client in current process is Owner
		IF DoesExist(TxLifeRequest.OLifE.Party[1].Owner) == "true"
		{
			BRANCH TARGET5224;
		}
		#J03034 End
		# .
		# . 		...........  EMPLOYMENT section of Client Update ..............
		# .
		# Validation de l'occupation du participant.
		IF MIR-OCCP-ID != ""
		{
			# Get the garantee name in EDIT table
			STEP TARGET4576
			{
				USES P-STEP "BF0680-P";
				ATTRIBUTES
				{
					Explicit;
					GetMessages = "Yes";
				}
				"OCCCD" -> MIR-ETBL-TYP-ID;
				MIR-OCCP-ID -> MIR-ETBL-VALU-ID;
				"E" -> MIR-ETBL-LANG-CD;
				Occupation-name <- MIR-ETBL-DESC-TXT-T[1];
			}
			IF LSIR-RETURN-CD == "05" && Occupation-name == ""
			{
#				TRACE("MIR-OCCP-ID = "  + MIR-OCCP-ID + " " + MIR-CLI-ID);
#				TRACE("MIR-ETBL-DESC-TXT-T[1]= "  + MIR-ETBL-DESC-TXT-T[1] + " " + MIR-CLI-ID);
#				TRACE("Occupation-name= "  + Occupation-name + " " + MIR-CLI-ID);
				BRANCH TARGET4576;
			}
#			TRACE("LSIR-RETURN-CD BF0680-P Occupation = "  + LSIR-RETURN-CD + " " + MIR-OCCP-ID + " " + MIR-ETBL-DESC-TXT-T[1] + " " + Occupation-name + " " + MIR-CLI-ID);
			TxLifeResponse.OLifE.Party[1].Employment.EmployerName = MIR-DV-EMPLR-CLI-CO-NM-T[1];
##			TxLifeResponse.OLifE.Party[1].Person.EmployerName = MIR-DV-EMPLR-CLI-CO-NM-T[1];
			TxLifeResponse.OLifE.Party[1].Person.Occupation = Occupation-name;
			IF MIR-CLI-OCCP-CLAS-CD != ""
			{
				TxLifeResponse.OLifE.Party[1].Person.OccupClass.Value = GetDescription(MIR-CLI-OCCP-CLAS-CD, "OccupClass");
				TxLifeResponse.OLifE.Party[1].Person.OccupClass.tc = toTXLife(MIR-CLI-OCCP-CLAS-CD, "OccupClass");
			}
			TxLifeResponse.OLifE.Party[1].Person.EstRetireDate = MIR-CLI-PRPS-RETIR-DT;
		}
		ELSE
		{
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600032";
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
			msgindex = msgindex + 1;
		}
		TARGET5224:

		# .
		# .
		# .                    ..............     Create Address Objects     ..............
		# .
		# .
		# Use BF0494-P Address List to retrieve a list of address records
		STEP TARGET6426
		{
			USES P-STEP "BF0494-P";
			"PR" -> MIR-CLI-ADDR-TYP-CD;
#			"" -> MIR-CLI-ADDR-SEQ-NUM;
			"N" -> MIR-DISPLAY-MSGS-IND;
		}
		IF LSIR-RETURN-CD == "05"
		{
			BRANCH TARGET6426;
		}

#		TRACE("LSIR-RETURN-CD BF0494-P  Address List = "  + LSIR-RETURN-CD);
		# Loop through the list of address records and create an Address Object for each one.
		IF MIR-CLI-ADDR-STAT-CD-T[1] == "E" || MIR-CLI-ADDR-STAT-CD-T[1] == "I"
		{
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			IF MIR-CLI-ADDR-STAT-CD-T[1] == "E"
			{
				TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600033";
			}
			IF MIR-CLI-ADDR-STAT-CD-T[1] == "I" 
			{
				TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600034";
			}
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
			IF DoesExist(TxLifeRequest.OLifE.Party[1].Owner) == "true"
			{
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID + " - " + WS-OWNER;
			}
			ELSE
			{
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID + " - " + WS-INSRD;
			}
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
			msgindex = msgindex + 1;
			BRANCH TARGET6565;
		}
		MIR-CLI-ADDR-TYP-CD = MIR-CLI-ADDR-TYP-CD-T[1];
		MIR-CLI-ADDR-EFF-DT = MIR-CLI-ADDR-EFF-DT-T[1];
		LSIR-RETURN-CD = "00";
		STEP TARGET6236
		{
			USES P-STEP "BF0490-P";
			"N" -> MIR-DISPLAY-MSGS-IND;
		}
		TRACE("LSIR-RETURN-CD BF0490-P  Address Retreive = "  + LSIR-RETURN-CD);
		TRACE("MIR-CLI-ID BF0490-P  CLIENT Address Retreive = "  + MIR-CLI-ID);	
		IF LSIR-RETURN-CD == "05"
		{
			BRANCH TARGET6236;
		}
		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03" && LSIR-RETURN-CD != "05"
		{
			# The Address retrieve didn't work.
			# Assign the error value "2" to the result code since this isn't the primary transaction.
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultCode.tc = "2";
			index = 1;
			WHILE MESSAGES-T[index] != ""
			{
				IF MessageSeverity(MESSAGES-T[index]) > 2
				{
					IF SESSION.LSIR-USER-LANG-CD == "E"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = " Client Address: " + MESSAGES-T[index];
					}
					ELSE
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Adresse client: " + MESSAGES-T[index];
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
					msgindex = msgindex + 1;
				}
				index = index + 1;
			}
			# Branch to next section.
			BRANCH TARGET6565;
		}
		TxLifeResponse.OLifE.Party[1].Address[index].AddressTypeCode.Value = GetDescription(MIR-CLI-ADDR-TYP-CD, "AddressTypeCode");
		TxLifeResponse.OLifE.Party[1].Address[index].AddressTypeCode.tc = toTXLife(MIR-CLI-ADDR-TYP-CD, "AddressTypeCode");
		TxLifeResponse.OLifE.Party[1].Address[index].AddressID = MIR-CLI-ADDR-SEQ-NUM;
		TxLifeResponse.OLifE.Party[1].Address[index].Line1 = MIR-CLI-ADDR-LN-1-TXT-T[1];
		TxLifeResponse.OLifE.Party[1].Address[index].Line2 = MIR-CLI-ADDR-LN-2-TXT-T[1];
		TxLifeResponse.OLifE.Party[1].Address[index].Line3 = MIR-CLI-ADDR-LN-3-TXT-T[1];
		IF MIR-CLI-RES-NUM-T[1] != ""
		{
		STEP TARGET4585
			{
				USES P-STEP "BF0680-P";
				ATTRIBUTES
				{
					Explicit;
					GetMessages = "No";
				}
				"RESD" -> MIR-ETBL-TYP-ID;
				MIR-CLI-RES-TYP-CD-T[1] -> MIR-ETBL-VALU-ID;
				MIR-CLI-LANG-CD -> MIR-ETBL-LANG-CD;
				ResdTypeTxt <- MIR-ETBL-DESC-TXT-T[1];
			}
			TxLifeResponse.OLifE.Party[1].Address[index].Line2 = ResdTypeTxt + " " + MIR-CLI-RES-NUM-T[1];
			IF MIR-CLI-ADDR-LN-2-TXT-T[1] != ""
			{
				TxLifeResponse.OLifE.Party[1].Address[index].Line2 = ResdTypeTxt + " " + MIR-CLI-RES-NUM-T[1] + ", " +  MIR-CLI-ADDR-LN-2-TXT-T[1];
			}
		}
		IF MIR-CLI-CRNT-LOC-CD-1 != "" && MIR-CLI-CRNT-LOC-CD-1 != "XX"
		{
			TxLifeResponse.OLifE.Party[1].Address[index].AddressStateTC.Value = GetDescription(MIR-CLI-CRNT-LOC-CD-1, "StateTC");
			TxLifeResponse.OLifE.Party[1].Address[index].AddressStateTC.tc = toTXLife(MIR-CLI-CRNT-LOC-CD-1, "StateTC");
		
		}
		IF MIR-CLI-CTRY-CD-1 != ""
		{
			TxLifeResponse.OLifE.Party[1].Address[index].AddressCountry.Value = GetDescription(MIR-CLI-CTRY-CD-1, "CountryTC");
			TxLifeResponse.OLifE.Party[1].Address[index].AddressCountry.tc = toTXLife(MIR-CLI-CTRY-CD-1, "CountryTC");
		}
		TxLifeResponse.OLifE.Party[1].Address[index].Zip = MIR-CLI-PSTL-CD-1;
		TxLifeResponse.OLifE.Party[1].Address[index].City = MIR-CLI-CITY-NM-TXT-T[1];
		# Build the AddressKey
		# The AddressKey requires that each field is of a set size.
		# Add spaces to the current value of MIR-CLI-ID until it's the proper length.
		ClientIdSize = 10;
		temp-MIR-CLI-ID = MIR-CLI-ID;
		WHILE LENGTH(temp-MIR-CLI-ID) < ClientIdSize
		{
			temp-MIR-CLI-ID = temp-MIR-CLI-ID + " ";
		}
		# Add spaces to the current value of type code until it's the proper length.
		TypeSize = 2;
		temp-MIR-CLI-ADDR-TYP-CD = MIR-CLI-ADDR-TYP-CD;
		WHILE LENGTH(temp-MIR-CLI-ADDR-TYP-CD) < TypeSize
		{
			temp-MIR-CLI-ADDR-TYP-CD = temp-MIR-CLI-ADDR-TYP-CD + " ";
		}
		TxLifeResponse.OLifE.Party[1].Address[index].AddressKey = temp-MIR-CLI-ID + temp-MIR-CLI-ADDR-TYP-CD + MIR-CLI-ADDR-SEQ-NUM;

		TARGET6565:

		# .
		# .
		# .                   ..............     Create PriorName Objects    ..............
		# .
		# .
		# Use BF1924 Previous Name List to retrieve a list of all....
		# We won't check the return code for this P-Step since it returns a "05" when there are no records found.
		STEP TARGET2462
		{
			USES P-STEP "BF1924-P";
			ATTRIBUTES
			{
				GetMessages = "No";
			}
			"N" -> MIR-DISPLAY-MSGS-IND;
		}
		# Loop through the list of previous name records and create a PriorName object for each one.
		index = 1;
		WHILE MIR-CLI-INDV-SEQ-NUM-T[index] != ""
		{
			STEP TARGET9836
			{
				USES P-STEP "BF1920-P";
				MIR-CLI-INDV-SEQ-NUM-T[index] -> MIR-CLI-INDV-SEQ-NUM;
			}
			TxLifeResponse.OLifE.Party[1].PriorName[index].FirstName = MIR-DV-ENTR-GIV-NM-T[1];
			TxLifeResponse.OLifE.Party[1].PriorName[index].LastName = MIR-DV-ENTR-SUR-NM-T[1];
			TxLifeResponse.OLifE.Party[1].PriorName[index].MiddleName = MIR-DV-CLI-INDV-MID-NM-T[1];
			TxLifeResponse.OLifE.Party[1].PriorName[index].Suffix = MIR-DV-CLI-INDV-SFX-NM-T[1];
			index = index + 1;
		}
		#J03034 - Bypass Create Phone and Email Objects, Create Income Information and Create Height Information if the client in current process is OWNER
		IF DoesExist(TxLifeRequest.OLifE.Party[1].Owner) == "true"
		{
			BRANCH TARGET7643;
		}
		#J03034 End
		# .
		# .
		# .                   ..............     Create Phone and Email Objects     ..............
		# .
		# .
		# Use BF1074 Client Contact List to retrieve a list of phone numbers for the client. In INGENIUM, the
		# the e-mail address is recorded as a type of phone number so we'll create both Phone and EMail objects
		# in this section.
		STEP TARGET4334
		{
			USES P-STEP "BF1074-P";
			"Y" -> MIR-NOT-DISPLAY-MSGS;
		}
#		TRACE("LSIR-RETURN-CD BF1074-P + CLI-ID = " + LSIR-RETURN-CD + " - " + MIR-CLI-ID);
		IF LSIR-RETURN-CD == "05"
		{
			BRANCH TARGET4334;
		}
		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03" && LSIR-RETURN-CD != "05"
		{
			# The Address retrieve didn't work.
			# Assign the error value "2" to the result code since this isn't the primary transaction.
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultCode.tc = "2";
			index = 1;
			WHILE MESSAGES-T[index] != ""
			{
				IF MessageSeverity(MESSAGES-T[index]) > 2
				{
					IF SESSION.LSIR-USER-LANG-CD == "E"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Phone Client: " + MESSAGES-T[index];
					}
					ELSE
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Client Coordonnés: " + MESSAGES-T[index];
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
					msgindex = msgindex + 1;
				}

				index = index + 1;
			}

			# Branch to next section.
			BRANCH TARGET5489;
		}
		LSIR-RETURN-CD = "00";
		# Loop through the list on phone numbers and create a Phone object for each one.
		# Initialize variables
		index = 1;
		phnindex = 1;
		emindex = 1;
		WHILE index < 11
		{
			# Check to make sure the record exists and isn't an e-mail record, then create the Phone objects
			IF MIR-CLI-CNTCT-ID-CD-T[index] != "" && MIR-CLI-CNTCT-ID-CD-T[index] != "EM" && MIR-CLI-CNTCT-ID-CD-T[index] != "CO" && MIR-CLI-CNTCT-ID-CD-T[index] != "PA" && MIR-CLI-CNTCT-ID-CD-T[index] != "FX" && MIR-CLI-CNTCT-ID-CD-T[index] != "TA"
			{
				# The phone number must be at least 12 characters long formatted xxx-xxx-xxxx
				IF LENGTH(MIR-CLI-CNTCT-ID-TXT-T[index]) < "12" 
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3284;
				}
				#We have to check the first 12 caracters and the format should be as xxx-xxx-xxxx
				# If the field is 12 characters long, it only has an area code and phone number.
				IF NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 3)) < 199 || NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 3)) > 999
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3284;				
				}
				IF NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 5, 3)) < 000 || NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 5, 3)) > 999
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3284;				
				}				
				IF NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 9, 4)) < 0000 || NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 9, 4)) > 9999
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3284;				
				}				
				IF SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 4, 1) != "-" || SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 8, 1)!= "-"
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3284;				
				}				
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].AreaCode = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index],1,3);
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].DialNumber = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index],5,8);
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].PhoneTypeCode.Value = GetDescription(MIR-CLI-CNTCT-ID-CD-T[index], "PhoneTypeCode");
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].PhoneTypeCode.tc = toTXLife(MIR-CLI-CNTCT-ID-CD-T[index], "PhoneTypeCode");
				phnindex = phnindex + 1;
			}
			# Check to see if the phone number is actually an e-mail address and create an EMail object
			IF MIR-CLI-CNTCT-ID-CD-T[index] != "" && (MIR-CLI-CNTCT-ID-CD-T[index] == "EM" || MIR-CLI-CNTCT-ID-CD-T[index] == "CO")
			{
				TxLifeResponse.OLifE.Party[1].EMailAddress[emindex].AddrLine = MIR-CLI-CNTCT-ID-TXT-T[index];
				emindex = emindex + 1;
			}
			TARGET3284:
			index = index + 1;
		}
		TARGET5489:
		
		# .
		# .
		# .                   ..............     Create Income Information     ..............
		# .
		# .
		# Use BF1064 Income List to retrieve a list of all income records. We send ACORD information from the
		# most recent record, this will always be sequence 001.
		# We won't check the return code for this P-Step since it returns a "05" when there are no records found.
		STEP TARGET3456
		{
			USES P-STEP "BF1064-P";
			"N" -> MIR-DISPLAY-MSGS-IND;
		}
		# Check to see if there is at least 1 record returned. If there is, the first record is the most recent
		# and the one we'll use. If not, then there are no income records for the client and we can skip this
		# section.
		IF MIR-CLI-INCM-EFF-DT-T[1] != ""
		{
			STEP TARGET4273
			{
				USES P-STEP "BF1060-P";
				MIR-CLI-INCM-EFF-DT-T[1] -> MIR-CLI-INCM-EFF-DT;
				"N" -> MIR-DISPLAY-MSGS-IND;
			}

			IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03"
			{
				# The Income retrieve didn't work.
				# Assign the error value "2" to the result code since this isn't the primary transaction.
				TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
				TxLifeResponse.TransResult.ResultCode.tc = "2";
				index = 1;
				WHILE MESSAGES-T[index] != ""
				{
					IF MessageSeverity(MESSAGES-T[index]) > 2
					{
						IF SESSION.LSIR-USER-LANG-CD == "E"
						{
							TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Client Income: " + MESSAGES-T[index];
						}
						ELSE
						{
							TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Revenu Client: " + MESSAGES-T[index];
						}
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
						TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
						msgindex = msgindex + 1;
					}

					index = index + 1;
				}

				# Branch to next section.
				BRANCH TARGET4457;
			}
			LSIR-RETURN-CD = "00"; 
			TxLifeResponse.OLifE.Party[1].Person.EstSalary = RemoveLeadingZero(MIR-CLI-EARN-INCM-AMT);
			TxLifeResponse.OLifE.Party[1].Person.EstGrossAnnualOtherIncome = RemoveLeadingZero(MIR-CLI-OTHR-INCM-AMT);
			TxLifeResponse.OLifE.Party[1].Person.EstNetWorth = RemoveLeadingZero(MIR-CLI-NET-WRTH-AMT);
		}

		TARGET4457:

		# .
		# .
		# .                    ..............     Create Height Information     ..............
		# .
		# .
		# Use BF0540 Physcian/Personal Information Inquiry to retrieve height information
		STEP TARGET2121
		{
			USES P-STEP "BF0540-P";
			ATTRIBUTES
			{
				GetMessages = "NO";
			}
			"N" -> MIR-CHCK-CLI-CNFD-IND;
			"N" -> MIR-DISPLAY-MSGS-IND;
		}
#		TRACE("LSIR-RETURN-CD BF0540-P Height Info= " + LSIR-RETURN-CD);
		IF LSIR-RETURN-CD == "05"
		{
			BRANCH TARGET2121;
		}
	
		# Check to see if Height information exists
		IF MIR-DV-CLI-CM-HT != ""
		{
			# Height is given in both imperial and metric measure. Assign imperial fields to the response.
			# This could be changed to use metric.
			
			TxLifeResponse.OLifE.Party[1].Person.Height2.MeasureUnits.tc = toTXLife("2", "MeasureUnits");
			TxLifeResponse.OLifE.Party[1].Person.Height2.MeasureUnits.Value = GetDescription("2", "MeasureUnits");
			
			# The height measure value must be calculated using the Feet and Inches fields.
			# In order to do the calculation, the fields must be converted to numeric values.
			# After the value calculated, the result needs to be converted back to a string to send out in the response.
			
			MIR-DV-CLI-FT-HT = NUMBER(MIR-DV-CLI-FT-HT);
			MIR-DV-CLI-INCH-HT = NUMBER(MIR-DV-CLI-INCH-HT);
			TxLifeResponse.OLifE.Party[1].Person.Height2.MeasureValue = STRING(MIR-DV-CLI-INCH-HT + MIR-DV-CLI-FT-HT * 12);
		}

		# Check to see if Weight information exists
		IF MIR-DV-CLI-LB-WGT != ""
		{
			# Weight is given in both imperial and metric measure. Assign imperial fields to response.
			# This could be changed to use metric.
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			TxLifeResponse.OLifE.Party[1].Person.Weight2.MeasureUnits.tc = toTXLife("2", "MeasureUnits");
			TxLifeResponse.OLifE.Party[1].Person.Weight2.MeasureUnits.Value = GetDescription("2", "MeasureUnits");
			TxLifeResponse.OLifE.Party[1].Person.Weight2.MeasureValue = MIR-DV-CLI-LB-WGT;
		}
		BRANCH TARGET7643;
	}

	# ............................................... Producer Information ..............................................................................................
	# .
	# .        ..........     Create information for Producer records     ..........
	# .
	# .
	# Check to see if the CompanyProducerID is given. If it is, this Party is an Agent.
	IF DoesExist(TxLifeRequest.OLifE.Party[1].Producer.CompanyProducerID) == "true"
	{
		MIR-CLI-ID = TxLifeRequest.OLifE.Party[1].Producer.CompanyProducerID;
		# Use BF1220 Client Inquiry to retrieve the client record, this done for all inquiry levels
		STEP TARGET2836
		{
			USES P-STEP "BF1220-P";
			"N" -> MIR-CHCK-CLI-CNFD-IND;
		}

		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03"
		{
			# The retrieve didn't work.
			# Assign the error value "5" to the result code and branch to the end of the flow.
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			IF SESSION.LSIR-USER-LANG-CD == "E"
			{
				TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Agent not found: " + MESSAGES-T[index];
			}
			ELSE
			{
				TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Agent inexistant: " + MESSAGES-T[index];
			}
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
			msgindex = msgindex + 1;
			BRANCH TARGET7643;
		}

		TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;

		IF MIR-CLI-SEX-CD == "C"
		{
			#J03034 begin
			IF MIR-CLI-CO-ENTR-NM-T[1] == ""
			{
				# The client retrieve didn't work.
				# Assign the error value "5" to the result code and branch to the end of the flow.
				TxLifeResponse.TransResult.ResultCode.tc = "5";
				IF SESSION.LSIR-USER-LANG-CD == "E"
				{
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Agent Name not found: " + MIR-CLI-ID;
				}
				ELSE
				{
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Nom d'agent inexistant: " + MIR-CLI-ID;
				}
				TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
				TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
				TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
				msgindex = msgindex + 1;
				BRANCH TARGET7643;
			}
			#J03034 End
			SubCar = 30;
			IF SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 30, 1) != " " && SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 31, 1) != " "
			{
				WHILE SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], SubCar, 1) != " " && SubCar > 1
				{
					SubCar = SubCar - 1;
				}
				IF SubCar == 1
				{
					TxLifeResponse.OLifE.Party[1].Person.FirstName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, 30);
					TxLifeResponse.OLifE.Party[1].Person.LastName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 31, 20);
				}
				ELSE
				{
					TxLifeResponse.OLifE.Party[1].Person.FirstName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, SubCar);
					SubCar = SubCar + 1;
					SubCarEnd = 50 - SubCar;
					TxLifeResponse.OLifE.Party[1].Person.LastName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], SubCar, SubCarEnd);
				}
			}
			 
			IF SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 30, 1) != " " && SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 31, 1) == " "
			{
				TxLifeResponse.OLifE.Party[1].Person.FirstName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, 30);
				TxLifeResponse.OLifE.Party[1].Person.LastName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 31, 20);
			}
			IF SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 30,1) == " " 
			{
				TxLifeResponse.OLifE.Party[1].Person.FirstName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 1, 30);
				TxLifeResponse.OLifE.Party[1].Person.LastName = SUBSTRING(MIR-CLI-CO-ENTR-NM-T[1], 31, 20);
			}

			TxLifeResponse.OLifE.Party[1].FullName = MIR-CLI-CO-ENTR-NM-T[1];
			TxLifeResponse.OLifE.Party[1].GovtID = MIR-CLI-TAX-ID;
			TxLifeResponse.OLifE.Party[1].GovIDTC.tc = toTXLife("2", "GovIDTC");
			TxLifeResponse.OLifE.Party[1].GovIDTC.Value = GetDescription("2", "GovIDTC");
		}
		ELSE
		{
#			TxLifeResponse.OLifE.Party[1].Person.Title = MIR-CLI-INDV-TITL-TXT-T[1];
			TxLifeResponse.OLifE.Party[1].Person.FirstName = MIR-ENTR-GIV-NM-T[1];
			TxLifeResponse.OLifE.Party[1].Person.MiddleName = MIR-CLI-INDV-MID-NM-T[1];
			TxLifeResponse.OLifE.Party[1].Person.LastName = MIR-ENTR-SUR-NM-T[1];
			TxLifeResponse.OLifE.Party[1].Person.Suffix = MIR-CLI-INDV-SFX-NM-T[1];
		}
		MIR-AGT-ID = TxLifeRequest.OLifE.Party[1].Producer.CompanyProducerID;
		# .
		# .
		# .                   ..............     Check for Agent Information     ..............
		# .
		# .
		# Use BF1420-P Agent Inquiry to retrieve agent information.
		STEP TARGET2743
		{
			USES P-STEP "BF1420-P";
		}

		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03"
		{
			# The retrieve didn't work.
			# Assign the error value "5" to the result code and branch to the end of the flow.
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			index = 1;
			WHILE MESSAGES-T[index] != ""
			{
				IF MessageSeverity(MESSAGES-T[index]) > 2
				{
					IF SESSION.LSIR-USER-LANG-CD == "E"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Agent Information: " + MESSAGES-T[index];
					}
					ELSE
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Information agent: " + MESSAGES-T[index];
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
					msgindex = msgindex + 1;
				}

				index = index + 1;
			}
			BRANCH TARGET7643;
		}

#		TxLifeResponse.OLifE.Party[1].Producer.CarrierAppointment.AppState = MIR-LIC-LOC-CD;
#		TxLifeResponse.OLifE.Party[1].Producer.CarrierAppointment.EffDate = MIR-AGT-CNTRCT-STRT-DT;
#		TxLifeResponse.OLifE.Party[1].Producer.CarrierAppointment.ExpDate = MIR-AGT-CNTRCT-TRMN-DT;
#		TxLifeResponse.OLifE.Party[1].Producer.CarrierAppointment.CarrierApptStatus = MIR-AG-STAT-CD;
		TxLifeResponse.OLifE.Party[1].Producer.CarrierAppointment.CompanyProducerID = MIR-AGT-ID;
		
		#Begine of change 03mar2008
		IF MIR-ADDR-BOX-CD != ""
		{
			TxLifeResponse.OLifE.Party[1].KeyedValue.KeyName = "agentRoutingNumber";
			TxLifeResponse.OLifE.Party[1].KeyedValue.KeyValue = MIR-ADDR-BOX-CD;
		}
		#End of change 03mar2008

		# .
		# .
		# .                   ..............     Create Producer's Phone and Email Objects     ..............
		# .
		# .
		# Use BF1074 Client Contact List to retrieve a list of phone numbers for the client. In INGENIUM, the
		# the e-mail address is recorded as a type of phone number so we'll create both Phone and EMail objects
		# in this section.
		STEP TARGET4335
		{
			USES P-STEP "BF1074-P";
			"Y" -> MIR-NOT-DISPLAY-MSGS;
		}
#		TRACE("LSIR-RETURN-CD BF1074-P = " + LSIR-RETURN-CD);

		IF LSIR-RETURN-CD != "00" && LSIR-RETURN-CD != "03" && LSIR-RETURN-CD != "05"
		{
			# The Address retrieve didn't work.
			# Assign the error value "5" to the result code since this isn't the primary transaction.
			TxLifeResponse.OLifE.Party[1].PartyKey = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultCode.tc = "5";
			index = 1;
			WHILE MESSAGES-T[index] != ""
			{
				IF MessageSeverity(MESSAGES-T[index]) > 2
				{
					IF SESSION.LSIR-USER-LANG-CD == "E"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Phone Agent: " + MESSAGES-T[index];
					}
					ELSE
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Agent coordonnés: " + MESSAGES-T[index];
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
					msgindex = msgindex + 1;
				}

				index = index + 1;
			}

			# Branch to next section.
			BRANCH TARGET7643;
		}

		# Loop through the list on phone numbers and create a Phone object for each one.
		# Initialize variables
		index = 1;
		phnindex = 1;
		emindex = 1;
		WHILE index < 11
		{
			# Check to make sure the record exists and isn't an e-mail record, then create the Phone objects
			IF MIR-CLI-CNTCT-ID-CD-T[index] != "" && MIR-CLI-CNTCT-ID-CD-T[index] != "EM" && MIR-CLI-CNTCT-ID-CD-T[index] != "CO" && MIR-CLI-CNTCT-ID-CD-T[index] != "PA" && MIR-CLI-CNTCT-ID-CD-T[index] != "FX" && MIR-CLI-CNTCT-ID-CD-T[index] != "TA"
			{
				# The phone number must be at least 12 characters long formatted xxx-xxx-xxxx
				IF LENGTH(MIR-CLI-CNTCT-ID-TXT-T[index]) < "12" 
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3285;
				}
				#We have to check the first 12 caracters and the format should be as xxx-xxx-xxxx
				# If the field is 12 characters long, it only has an area code and phone number.
				IF NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 3)) < 199 || NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 3)) > 999
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3285;				
				}
				IF NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 5, 3)) < 000 || NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 5, 3)) > 999
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3285;				
				}				
				IF NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 9, 4)) < 0000 || NUMBER(SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 9, 4)) > 9999
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3285;				
				}				
				IF SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 4, 1) != "-" || SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 8, 1)!= "-"
				{
					TxLifeResponse.TransResult.ResultCode.tc = "5";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "XS92600038";
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "HO"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-HO;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "BU"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-BU;
					}
					IF MIR-CLI-CNTCT-ID-CD-T[index] == "CP"
					{
						TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm2 = WS-CP;
					}
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoParm3 = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index], 1, 12);
					TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "200";
					TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "Failure";
					msgindex = msgindex + 1;
					BRANCH TARGET3285;				
				}				
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].AreaCode = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index],1,3);
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].DialNumber = SUBSTRING(MIR-CLI-CNTCT-ID-TXT-T[index],5,8);
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].PhoneTypeCode.Value = GetDescription(MIR-CLI-CNTCT-ID-CD-T[index], "PhoneTypeCode");
				TxLifeResponse.OLifE.Party[1].Phone[phnindex].PhoneTypeCode.tc = toTXLife(MIR-CLI-CNTCT-ID-CD-T[index], "PhoneTypeCode");
				phnindex = phnindex + 1;
			}
			# Check to see if the phone number is actually an e-mail address and create an EMail object
			IF MIR-CLI-CNTCT-ID-CD-T[index] != "" && (MIR-CLI-CNTCT-ID-CD-T[index] == "EM"  || MIR-CLI-CNTCT-ID-CD-T[index] == "CO")
			{
				TxLifeResponse.OLifE.Party[1].EMailAddress[emindex].AddrLine = MIR-CLI-CNTCT-ID-TXT-T[index];
				emindex = emindex + 1;
			}
			TARGET3285:
			index = index + 1;
		}
	}

	# .
	# .
	# .        ..........     Create information for Carrier records     ..........
	# .
	# .
	# Check to see if the CarrierCode is given. If it has, this Party is a carrier.
	# A CarrierCode party could be created here.
	IF DoesExist(TxLifeRequest.OLifE.Party[1].Carrier.CarrierCode) == "true"
	{
	}

	# If the flow came this way there will be messages in the ResultInfo fields.
	# Skip the error handling section to avoid replacing them.
	BRANCH TARGET8329;
	TARGET7643:
	BRANCH TARGET8329;

	# .
	# .
	# .          ................     Build Response     ...............
	# .
	# .
	# If the request resulted in an error the result code will have a value other then 1.
	# In this case we need to move the messages to the result info desc fields
	IF TxLifeResponse.TransResult.ResultCode.tc != "1"
	{
		index = 1;
		WHILE MESSAGES-T[index] != ""
		{
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoDesc = "Final Response: " + MESSAGES-T[index];
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.tc = "100";
			TxLifeResponse.TransResult.ResultInfo[msgindex].Party_Key = MIR-CLI-ID;
			TxLifeResponse.TransResult.ResultInfo[msgindex].ResultInfoCode.Value = "General Error";
			index = index + 1;
			msgindex = msgindex + 1;
		}

	}

	TARGET8329:

	IF TxLifeResponse.TransResult.ResultCode.tc == "1" || TxLifeResponse.TransResult.ResultCode.tc == "2"
	{
		TxLifeResponse.TransResult.ConfirmationID = "1";
	}

	TxLifeResponse.TransResult.ResultCode.Value = GetDescription(TxLifeResponse.TransResult.ResultCode.tc, "ResultCode");
	TxLifeResponse.TransRefGUID = TxLifeRequest.TransRefGUID;
	TxLifeResponse.TransType.tc = TxLifeRequest.TransType;
	TxLifeResponse.TransType.Value = "Party Inquiry";
	TxLifeResponse.TransExeDate = SESSION.LSIR-SYS-DT-EXT;
	time = SESSION.LSIR-SYS-TIME;
	formatted-time = SUBSTRING(time,1,2) + ":" + SUBSTRING(time,3,2) + ":" + SUBSTRING(time,5,2);
	TxLifeResponse.TransExeTime = formatted-time;
	TxLifeResponse.TransMode = TxLifeRequest.TransMode;
	#Send back the response to the calling flow
	response = TxLifeResponse;
}
