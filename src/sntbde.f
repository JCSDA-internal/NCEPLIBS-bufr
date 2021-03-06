C> @file
C> @author ATOR @date 2007-01-19
	
C> THIS SUBROUTINE PARSES THE FIRST LINE OF AN ENTRY THAT WAS
C>   PREVIOUSLY READ FROM AN ASCII MASTER TABLE D FILE AND STORES THE
C>   OUTPUT INTO THE MERGED ARRAYS.  IT THEN READS AND PARSES ALL
C>   REMAINING LINES FOR THAT SAME ENTRY AND THEN LIKEWISE STORES THAT
C>   OUTPUT INTO THE MERGED ARRAYS.  THE RESULT IS THAT, UPON OUTPUT,
C>   THE MERGED ARRAYS NOW CONTAIN ALL OF THE INFORMATION FOR THE
C>   CURRENT TABLE ENTRY.
C>
C> PROGRAM HISTORY LOG:
C> 2007-01-19  J. ATOR    -- ORIGINAL AUTHOR
C> 2021-01-08  J. ATOR    -- MODIFIED MSTABS ARRAY DECLARATIONS
C>                           FOR GNUv10 PORTABILITY
C>
C> USAGE:    CALL SNTBDE ( LUNT, IFXYN, LINE, MXMTBD, MXELEM,
C>                         NMTBD, IMFXYN, CMMNEM, CMDSC, CMSEQ,
C>                         NMELEM, IEFXYN, CEELEM )
C>   INPUT ARGUMENT LIST:
C>     LUNT     - INTEGER: FORTRAN LOGICAL UNIT NUMBER OF ASCII FILE
C>                CONTAINING MASTER TABLE D INFORMATION
C>     IFXYN    - INTEGER: BIT-WISE REPRESENTATION OF FXY NUMBER FOR
C>                TABLE ENTRY; THIS FXY NUMBER IS THE SEQUENCE DESCRIPTOR
C>     LINE     - CHARACTER*(*): FIRST LINE OF TABLE ENTRY
C>     MXMTBD   - INTEGER: MAXIMUM NUMBER OF ENTRIES TO BE STORED IN
C>                MERGED MASTER TABLE D ARRAYS; THIS SHOULD BE THE SAME
C>                NUMBER AS WAS USED TO DIMENSION THE OUTPUT ARRAYS IN
C>                THE CALLING PROGRAM, AND IT IS USED BY THIS SUBROUTINE
C>                TO ENSURE THAT IT DOESN'T OVERFLOW THESE ARRAYS
C>     MXELEM   - INTEGER: MAXIMUM NUMBER OF ELEMENTS TO BE STORED PER
C>                ENTRY WITHIN THE MERGED MASTER TABLE D ARRAYS; THIS
C>                SHOULD BE THE SAME NUMBER AS WAS USED TO DIMENSION THE
C>                OUTPUT ARRAYS IN THE CALLING PROGRAM, AND IT IS USED
C>                BY THIS SUBROUTINE TO ENSURE THAT IT DOESN'T OVERFLOW
C>                THESE ARRAYS
C>
C>   OUTPUT ARGUMENT LIST:
C>     NMTBD    - INTEGER: NUMBER OF ENTRIES IN MERGED MASTER TABLE D
C>                ARRAYS
C>     IMFXYN(*)- INTEGER: MERGED ARRAY CONTAINING BIT-WISE
C>                REPRESENTATIONS OF FXY NUMBERS (I.E. SEQUENCE
C>                DESCRIPTORS)
C>     CMMNEM(*)- CHARACTER*8: MERGED ARRAY CONTAINING MNEMONICS
C>     CMDSC(*) - CHARACTER*4: MERGED ARRAY CONTAINING DESCRIPTOR CODES 
C>     CMSEQ(*) - CHARACTER*120: MERGED ARRAY CONTAINING SEQUENCE NAMES
C>     NMELEM(*)- INTEGER: MERGED ARRAY CONTAINING NUMBER OF ELEMENTS
C>                STORED FOR EACH ENTRY
C>   IEFXYN(*,*)- INTEGER: MERGED ARRAY CONTAINING BIT-WISE
C>                REPRESENTATIONS OF ELEMENT FXY NUMBERS
C>   CEELEM(*,*)- CHARACTER*120: MERGED ARRAY CONTAINING ELEMENT NAMES 
C>
C> REMARKS:
C>    THIS ROUTINE CALLS:        ADN30    BORT     BORT2    IFXY
C>                               IGETFXY  IGETNTBL JSTCHR   NEMOCK
C>                               PARSTR
C>    THIS ROUTINE IS CALLED BY: RDMTBD
C>                               Normally not called by any application
C>                               programs.
C>
	SUBROUTINE SNTBDE ( LUNT, IFXYN, LINE, MXMTBD, MXELEM,
     .			    NMTBD, IMFXYN, CMMNEM, CMDSC, CMSEQ,
     .			    NMELEM, IEFXYN, CEELEM )



	CHARACTER*(*)	LINE
	CHARACTER*200	TAGS(10), CLINE
	CHARACTER*128	BORT_STR1, BORT_STR2
	CHARACTER*120	CEELEM(MXMTBD,MXELEM)
	CHARACTER*6	ADN30, ADSC, CLEMON
	CHARACTER*4	CMDSC(*)
	CHARACTER	CMSEQ(120,*)
	CHARACTER	CMMNEM(8,*)

	INTEGER		IMFXYN(*), NMELEM(*),
     .                  IEFXYN(MXMTBD,MXELEM)

	LOGICAL	DONE

C-----------------------------------------------------------------------
C-----------------------------------------------------------------------

	IF ( NMTBD .GE. MXMTBD ) GOTO 900
	NMTBD = NMTBD + 1

C	Store the FXY number.  This is the sequence descriptor.

	IMFXYN ( NMTBD ) = IFXYN

C	Is there any other information within the first line of the
C	table entry?  If so, it follows a "|" separator.

        DO II = 1, 8
	    CMMNEM ( II, NMTBD ) = ' '
        ENDDO
	CMDSC ( NMTBD ) = ' '
        DO II = 1, 120
	    CMSEQ ( II, NMTBD ) = ' '
        ENDDO
	IPT = INDEX ( LINE, '|' )
	IF ( IPT .NE. 0 ) THEN

C	    Parse the rest of the line.  Any of the fields may be blank.

	    CALL PARSTR ( LINE(IPT+1:), TAGS, 10, NTAG, ';', .FALSE. )
	    IF ( NTAG .GT. 0 ) THEN
C		The first additional field contains the mnemonic.
		CALL JSTCHR ( TAGS(1), IRET )
C		If there is a mnemonic, then make sure it's legal.
		IF ( ( IRET .EQ. 0 ) .AND.
     .		    ( NEMOCK ( TAGS(1) ) .NE. 0 ) ) THEN
		    BORT_STR2 = '                  HAS ILLEGAL MNEMONIC'
		    GOTO 901
		ENDIF
                DO II = 1, 8
		    CMMNEM ( II, NMTBD ) = TAGS(1)(II:II)
                ENDDO
	    ENDIF
	    IF ( NTAG .GT. 1 ) THEN
C		The second additional field contains descriptor codes.
		CALL JSTCHR ( TAGS(2), IRET )
		CMDSC ( NMTBD ) = TAGS(2)(1:4)
	    ENDIF
	    IF ( NTAG .GT. 2 ) THEN
C		The third additional field contains the sequence name.
		CALL JSTCHR ( TAGS(3), IRET )
                DO II = 1, 120
		    CMSEQ ( II, NMTBD ) = TAGS(3)(II:II)
                ENDDO
	    ENDIF
	ENDIF

C	Now, read and parse all remaining lines from this table entry.
C	Each line should contain an element descriptor for the sequence
C	represented by the current sequence descriptor.

	NELEM = 0
	DONE = .FALSE.
	DO WHILE ( .NOT. DONE ) 
	    IF ( IGETNTBL ( LUNT, CLINE ) .NE. 0 ) THEN
		BORT_STR2 = '                  IS INCOMPLETE'
		GOTO 901
	    ENDIF
	    CALL PARSTR ( CLINE, TAGS, 10, NTAG, '|', .FALSE. )
	    IF ( NTAG .LT. 2 ) THEN
		BORT_STR2 = '                  HAS BAD ELEMENT CARD'
		GOTO 901
	    ENDIF

C	    The second field contains the FXY number for this element.

	    IF ( IGETFXY ( TAGS(2), ADSC ) .NE. 0 ) THEN
		BORT_STR2 = '                  HAS BAD OR MISSING' //
     .			    ' ELEMENT FXY NUMBER'
		GOTO 901
	    ENDIF
	    IF ( NELEM .GE. MXELEM ) GOTO 900
	    NELEM = NELEM + 1
	    IEFXYN ( NMTBD, NELEM ) = IFXY ( ADSC )

C	    The third field (if it exists) contains the element name.

	    IF ( NTAG .GT. 2 ) THEN
		CALL JSTCHR ( TAGS(3), IRET )
		CEELEM ( NMTBD, NELEM ) = TAGS(3)(1:120)
	    ELSE
		CEELEM ( NMTBD, NELEM ) = ' '
	    ENDIF

C	    Is this the last line for this table entry?

	    IF ( INDEX ( TAGS(2), ' >' ) .EQ. 0 ) DONE = .TRUE.
	ENDDO
	NMELEM ( NMTBD ) = NELEM

	RETURN
	
 900	CALL BORT('BUFRLIB: SNTBDE - OVERFLOW OF MERGED ARRAYS')
 901	CLEMON = ADN30 ( IFXYN, 6 )
	WRITE(BORT_STR1,'("BUFRLIB: SNTBDE - TABLE D ENTRY FOR' //
     .     ' SEQUENCE DESCRIPTOR: ",5A)')    
     .     CLEMON(1:1), '-', CLEMON(2:3), '-', CLEMON(4:6)
	CALL BORT2(BORT_STR1,BORT_STR2)
	END
