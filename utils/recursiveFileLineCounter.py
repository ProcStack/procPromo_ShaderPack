# Written by Kevin Edzenga
#   Eh, was curious by the line count in my projects
#
# Was written for Antib0dy.Club website, so there is left over variables and func
#

from os import listdir, stat
from os.path import isfile, isdir, join, realpath
import re
import datetime
import math

# Update this as need be
repoName="procPromo"
statProjectTitle="ProcPromo Code Stats"

# Get the absolute route to base directory; repoName
basePath=re.split( r'[\\|/]', realpath(__file__) )
basePath="/".join( basePath[ 0:(basePath.index(repoName)+1) ] )

#Stats file output
statPath=[ basePath+"/utils/stats/ScriptingStats_", ".txt" ]

# Recursive Directories
dirs=[ basePath+'/shaders/' ]
avoidList=['shadow.glsl', 'shadow.fsh', 'shadow.vsh']
avoidExtensions=['.psd','.gif','.png','.jpg']

def printList(list):
    for l in list:
        print(l)
        
#The manual added files
filePaths=[
        #basePath+'/ReadMe.md',
    ]
serverFiles=[
    ]
    
coreCodeList=[]
coreCodeRoot="js"
coreCodeLocation=["programs"] # The core code for functionality 
artistRoomList=[]
exemptList=[]
    
# Recursively move through directories and gather all files
while len(dirs)>0:
    curDir=dirs.pop()
    
    pathSplit= list(filter(None, list( re.split( r'[/|\\]', curDir) )))
    coreCount=0
    for d in coreCodeLocation:
        if d in pathSplit:
            coreCount+=1
            
    exemptCheck=False
    for d in exemptList:
        if d in pathSplit:
            exemptCheck=True
    
    isCore= coreCount == len(coreCodeLocation) or exemptCheck or ( coreCount == len(coreCodeLocation)-1 and pathSplit[-1] == coreCodeRoot)
    isRoom= coreCount == len(coreCodeLocation)-1 and not exemptCheck and pathSplit[-1] != coreCodeRoot
    
    if isCore:
        coreCodeList += [join(curDir, f) for f in listdir(curDir) if isfile(join(curDir, f))] 
    elif isRoom:
        artistRoomList += [join(curDir, f) for f in listdir(curDir) if isfile(join(curDir, f))] 
    filePaths += [join(curDir, f) for f in listdir(curDir) if isfile(join(curDir, f))] 
    dirs += [join(curDir, f) for f in listdir(curDir) if isdir(join(curDir, f))] 



# Filter out files not ascii in nature
def filterByString(str):
    for x in range(len(avoidExtensions)):
        if avoidExtensions[x] in str :
            return False
    return True

filePaths = list(filter(filterByString, filePaths))



# Extention List
extFoundList=list(set([ x.split(".")[-1].upper() for x in filePaths]))
extFoundList.sort()

# Sort by name, swap delimiter just to be safe
filePathSorted=[ "/".join( re.split(r'[\\|/]',x) ) for x in filePaths  ]
filePathSorted.sort()

coreCodeList=[ "/".join( re.split(r'[\\|/]',x) ) for x in coreCodeList  ]
artistRoomList=[ "/".join( re.split(r'[\\|/]',x) ) for x in artistRoomList  ]



def bytesToHuman(bytes, pad=False):
    k=1024
    cur=bytes
    count=0
    while cur>=k:
        cur=cur/k
        count+=1
    disp= " "+[(" " if pad else "")+"B","KB","MB","GB","TB","PB"][count]
    hr=str(cur)
    if count==0 :
        hr= ( hr.rjust( 8, " " ) if pad else hr )+disp
    else:
        hr= hr.split(".") if "." in hr else [hr,'000']
        unit=len(hr[0])
        dec=4-unit
        if pad:
            hr[0]=hr[0].rjust(4, ' ')
            hr[1]=hr[1].ljust(dec,"0")[0:dec]
        else:
            hr[1]=hr[1][0:dec]
        hr=".".join(hr)+disp
    return hr;

# Gather total file size in human readable format
totalFileSize=0;
for f in filePathSorted:
    totalFileSize+=stat(f).st_size
totalFileSize=bytesToHuman(totalFileSize)


def lineCount(fpaths, spacer):
    global serverFiles
    global coreCodeList
    global artistRoomList
    totalCount=0
    totalNoWhiteSpaceCount=0
    totalCommentCount=0
    
    serverNoWhiteSpaceCount=0
    pxlNavNoWhiteSpaceCount=0
    artistRoomNoWhiteSpaceCount=0
    
    devCodeNoWhiteSpaceCount=0
    modCodeNoWhiteSpaceCount=0
    
    fileCount=0
    zfillCount=len(str(len(fpaths)))
    finalPrint=""
    while len(fpaths)>0:
        curfile=fpaths.pop()
        
        # Find files to avoid
        skipTrigger=False
        for avoid in avoidList:
            if avoid in curfile:
                skipTrigger=True
                break;
        if skipTrigger:
            continue
            
        isCoreCode= curfile in coreCodeList
        isArtistCode= curfile in artistRoomList
            
        commentBlockOpen=False
        devBlockOpen=False
        modBlockOpen=False
        
        isServerCode=False
        for f in serverFiles:
            if f in curfile:
                isServerCode=True
        
        curExt=curfile.split(".")[-1].lower()
        isTextOnly= curExt in ["txt", "md"]
        
        with open(curfile, encoding="utf-8") as f:
            fileCount+=1
            curLineCount=0
            curComments=0
            curWhiteSpace=0
            checkEmptyCommentLine=False
            print(curfile)
            print(f)
            for i, l in enumerate(f):
                commentRegistered=False
                curLineCount+=1
                totalCount+=1
                v=l
                
                if isTextOnly:
                    v=re.sub(r'( |\t|\r|\n)', '',  v) # Clean up any spaces, tabs, returns in the line
                    if len(v) >0 and v[0:2] != '//': # The line has info and isn't a comment
                        curComments+=1
                        totalCommentCount+=1
                    continue;
                
                # Find multi line comment blocks
                if not commentBlockOpen and "/*" in v and "*/" not in v: # Comment block is opening
                    checkEmptyCommentLine=True
                    commentBlockOpen=True
                    v=re.sub(r'((/\*).*)', '', v) # block start
                elif commentBlockOpen and "*/" in v and "/*" not in v: # Comment block is opening
                    checkEmptyCommentLine=True
                    commentBlockOpen=False
                    v=re.sub(r'(.*(\*/))', '', v) # block end
                if commentBlockOpen or (re.sub(r'( |\t|\r|\n)', '',  v) != '' and checkEmptyCommentLine ):  # If comment block open/close is NOT its own line
                    checkEmptyCommentLine=False
                    commentRegistered=True
                    curComments+=1
                    totalCommentCount+=1
                
                if not devBlockOpen and "//%=" in v: # Comment block is opening
                    devBlockOpen=True
                elif devBlockOpen and "//%" in v and "//%=" not in v: # Comment block is opening
                    devBlockOpen=False
                if devBlockOpen and re.sub(r'( |\t|\r|\n)', '',  v) != '':  # If comment block open/close is NOT its own line
                    devCodeNoWhiteSpaceCount+=1
                
                # Find dev only code comment blocks
                if not modBlockOpen and "//&=" in v: # Comment block is opening
                    modBlockOpen=True
                elif modBlockOpen and "//&" in v and "//&=" not in v: # Comment block is opening
                    modBlockOpen=False
                if modBlockOpen or (re.sub(r'( |\t|\r|\n)', '',  v) != '' and checkEmptyCommentLine ):  # If comment block open/close is NOT its own line
                    modCodeNoWhiteSpaceCount+=1
                
                # Single line comment blocks
                vtmp=v
                v=re.sub(r'(\/\*[\w\s\r\n\*\/]*\*\/)', '', v) # block self contained
                if v!=vtmp and not commentRegistered:
                    commentRegistered=True
                    curComments+=1
                # If no open multi line comment block, add in single line // comments and non white space
                if not commentBlockOpen:
                    v=re.sub(r'( |\t|\r|\n)', '',  v) # Clean up any spaces, tabs, returns in the line
                    if len(v) >0 and v[0:2] != '//': # The line has info and isn't a comment
                        totalNoWhiteSpaceCount+=1
                        if isCoreCode: # Core pxlNav file is open
                            pxlNavNoWhiteSpaceCount+=1
                        if isServerCode: # Server pxlNav file is open
                            serverNoWhiteSpaceCount+=1
                        if isArtistCode: # Artist Room file is open
                            artistRoomNoWhiteSpaceCount+=1
                        
                    if '//' in l and not commentRegistered: # Heyyy another comment!
                        commentRegistered=False
                        curComments+=1
                        totalCommentCount+=1
                # White space!!1!!112!@#!%@#$
                v=re.sub(r'( |\t|\r|\n)', '',  l)
                if v == '': # Check for just raw white space at all
                    curWhiteSpace+=1;
            # Append per-file stats to file data
            commentMin=curLineCount*.15
            addPref="** " if (curComments+1) < commentMin else "  "
            addSuf= " **" if "*" in addPref else ""
            addSufText= ("  ******** Expecting - "+str(int(commentMin))+"-"+str(int(commentMin*2))+"\n") if "*" in addPref else ""
            addCommentsText="\n** Add More Comments **" if "*" in addPref else ""
            fname="/".join( ['']+re.split(r'[\\|/]',curfile)[4::] )
            finalPrint+="\n"+addPref+"File #"+str(fileCount).zfill(zfillCount)+" - "+ fname + addSuf
            finalPrint+=addCommentsText
            finalPrint+="\n   - File Size - "+bytesToHuman( stat(curfile).st_size )
            finalPrint+="\n   - Total Line Count - "+str(curLineCount)
            finalPrint+="\n   - White Space Count - "+str(curWhiteSpace)
            finalPrint+="\n   - Comment Line Count - "+str(curComments)
            finalPrint+="\n"+addSufText+"\n"
    spacer="\n\n"+spacer+"\n\n"
    tab="    "
    dtab=tab+tab
    shift=tab+"         "
    # Stat File header
    header=""
    header+=tab+"Stats Overview - \n"
    header+=dtab+"File Types Checked - \n"+shift+(", ".join( extFoundList ))+"\n"
    header+=dtab+"Files Found - \n"+shift+str(fileCount)+"\n"
    header+=dtab+"Total Size Of Files - \n"+shift+str(totalFileSize)+"\n"
    header+=dtab+"Total File Line Count - \n"+shift+str(totalCount)+"\n\n"
    header+=dtab+"Code Line Count - \n"+shift+str(totalNoWhiteSpaceCount)+"\n"
    header+=dtab+"Commented Line Count - \n"+shift+str( totalCommentCount)
    header+=spacer
    header+=tab+"Web Only Line Counts - \n"
    header+=dtab+"Server Side pxlNav Line Count - \n"+shift+str(serverNoWhiteSpaceCount)+"\n"
    header+=dtab+"Front-End Core pxlNav Line Count - \n"+shift+str(pxlNavNoWhiteSpaceCount)+"\n"
    header+=dtab+"Artist Room Line Count - \n"+shift+str(artistRoomNoWhiteSpaceCount)+"\n\n"
    header+=dtab+"Developer Only Function Line Count - \n"+shift+str(devCodeNoWhiteSpaceCount)+"\n"
    header+=dtab+"Moderator Only Function Line Count - \n"+shift+str(modCodeNoWhiteSpaceCount)
    header+=spacer
    print(header)
    header+=finalPrint
    header+=spacer
    return header



# Gather Month Day, Year
date=datetime.datetime.now()
monthdayyear=" "+date.strftime("%B")+" "+str(date.day)+", "+str(date.year)+" "
spacer=" -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- "
padHeader=3
padDate=6
statProjectTitle=(" " if statProjectTitle[0] != " " else "") + statProjectTitle+(" " if statProjectTitle[-1] != " " else "")
padHeaderEnd=len(statProjectTitle)+padHeader
header="\n"+spacer[0:padHeader]+statProjectTitle+spacer[ padHeaderEnd:: ]
padEnd=len(monthdayyear)+padDate
# Set spacer design
header+="\n"+spacer[0:padDate]+monthdayyear+spacer[ padEnd:: ]+"\n"

print(header)



fileData = lineCount(filePathSorted, spacer)
fileData=header+fileData

date=datetime.datetime.now()
yearmonthday=str(date.year)+"-"+str(date.month)+"-"+str(date.day)
fileOut=yearmonthday.join( statPath )

f = open(fileOut, "w")
f.write(fileData)
f.close()
