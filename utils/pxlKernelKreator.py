# -- -- -- -- -- -- -- -- -- -- -- #
# -- Kernel Kreator -- -- -- -- -- #
# --   Kevin Edzenga; 2024 - -- -- #
# -- -- -- -- -- -- -- -- -- -- -- #

import os
import random
import re
import functools as ft

# Print an OpenGL 2D kernel array and run

runX = 5
runY = 5

kernelTypes = ["random","radial"]
kernelFormats = ["array","glsl"]

inMenu = True
isExit = False

kernelOpts = []
kernelOpts.append({
      "name" : "type",
      "value" : kernelTypes[0],
      "option" : kernelTypes,
      "label" : "Type Of Kernel",
      "help" : "Type of Kernel, Random Scatter or Radial out"
    })
kernelOpts.append({
      "name" : "format",
      "value" : kernelFormats[0],
      "option" : kernelFormats,
      "label" : "Output Formatting",
      "help" : ""
    })
kernelOpts.append({
      "name" : "runX",
      "value" : 5,
      "option" : "int",
      "label" : "Run X",
      "help" : "Output Column Count"
    })
kernelOpts.append({
      "name" : "runY",
      "value" : 5,
      "option" : "int",
      "label" : "Run Y",
      "help" : "Output Row Count"
    })
kernelOpts.append({
      "name" : "weightMin",
      "value" : 1.0,
      "option" : "float",
      "label" : "Min Value",
      "help" : ""
    })
kernelOpts.append({
      "name" : "weightMax",
      "value" : 4.0,
      "option" : "float",
      "label" : "Max Value",
      "help" : ""
    })
kernelOpts.append({
      "name" : "genNormalized",
      "value" : True,
      "option" : "bool",
      "label" : "Generate Normalized",
      "help" : ""
    })
kernelOpts.append({
      "name" : "_createKernel",
      "value" : False,
      "option" : "bool",
      "label" : "\033[33m-- \033[93mCreate Kernel \033[33m--\033[0m",
      "help" : "How you found this note."
    })
kernelOpts.append({
      "name" : "_help",
      "value" : False,
      "option" : "bool",
      "label" : "Help\033[33m ...\033[0m",
      "help" : "How you found this note."
    })
kernelOpts.append({
      "name" : "_exit",
      "value" : False,
      "option" : "bool",
      "label" : "Exit",
      "help" : "Quit Kernel Kreator"
    })

optIndex = {}


cliReset = "\033[0m"
cliBold = "\033[1m"
cliNumber = "\033[33m"
cliLabel = "\033[93m"
cliYellow = "\033[33m"
cliSelected = "\033[33m"
cliDim = "\033[90m"
cliInput = "\033[97m"

valueChars="█▓▒░ "



def clearPrompt():
    os.system('cls')
    
def formatOptions( opt ):
    ret=""
    if type(opt["option"]) == type([]):
        valStr = ""
        for c,v in enumerate(opt["option"]):
            limiter = ", "
            if c == len(opt["option"])-1:
                limiter=""
            if v == opt['value']:
                valStr+= f" {cliSelected}({c}) {v}{limiter}{cliReset}"
            else:
                valStr+= f" {cliDim}({c}) {v}{limiter}{cliReset}"
        ret+= f"\n      {valStr}"
    else:
        ret+= f"\n      {cliSelected}{opt['value']}{cliReset}"
    return ret

while not inMenu == False:
    hasHitUnders=False
    
    optDisplayStr = ""
    
    inSubMenu = not type(inMenu) == type(True)
    
    if inSubMenu:
        if inMenu in optIndex :
            opt = kernelOpts[ optIndex[inMenu] ]
            curOptStr = f"\n{cliNumber}{cliLabel}{opt['label']} --"
            curOptStr += formatOptions( opt )
            optDisplayStr += curOptStr
        optDisplayStr += f"{cliReset}\nEnter new value :"
    elif inMenu == True:
        for x,opt in enumerate(kernelOpts):
            curOptStr = f"\n{cliNumber}({x}) {cliLabel}{opt['label']}"
            curHelp=""
            if opt['name'] not in optIndex:
                optIndex[ opt['name'] ] = x
            try:
                if kernelOpts[optIndex["_help"]]["value"]:
                    curOptStr += f"{cliReset} -- {opt['help']}"
            except:
                pass;
                
            if "_" not in opt['name'] :
                curOptStr += formatOptions( opt )
            else:
                if hasHitUnders == False:
                    curOptStr = f"{cliReset}\n\n  -- -- --\n{curOptStr}"
                    hasHitUnders=True
            optDisplayStr += curOptStr
        optDisplayStr += f"{cliReset}\nEnter {cliYellow}0-{len(kernelOpts)-1}{cliReset} ({cliLabel}{optIndex['_createKernel']}{cliReset}) :"
    
    if "_help" in optIndex:
        kernelOpts[optIndex["_help"]]["value"]=False
    gridDisplayStr=""
    
    isRadial = False
    #   if kernelOpts[optIndex['format']]["value"] == "array":
    #elif kernelOpts[optIndex['format']]["value"] == "glsl":
    #if kernelOpts[optIndex['type']]["value"] == "random":
    if kernelOpts[optIndex['type']]["value"] == "radial":
        isRadial = True
    runX=kernelOpts[optIndex['runX']]["value"]
    runY=kernelOpts[optIndex['runY']]["value"]
    
    clearPrompt()
    centerDist = (( (float(runX)*.5) ** 2 ) + ( (float(runY)*.5) ** 2 )) ** .5
    for y in range( -1,runY ):
        for x in range( runX ):
            dispCar = "".join( random.choices( valueChars ) )
            if isRadial :
                dist = (( (float(runX)*.5-float(x)) ** 2 ) + ( (float(runY)*.5-float(y)) ** 2 )) ** .5
                #dist = dist / centerDist
                print(dist)
                dispCar = valueChars[ min(len(valueChars), int(len(valueChars)*dist))-1 ]
            curStr = f"|{dispCar}{dispCar}"
            curCap="|\n"
            if y == -1:
                curStr = " __"
                curCap="\n"
            elif y == runY-1:
                curCap="|"
            if x == runX-1:
                curStr += curCap
                curStr += cliReset
            gridDisplayStr += curStr
            
    
    print( gridDisplayStr )
    print( optDisplayStr )
    selOpt = input(f"{cliInput}  ")
    selMod = -1
    if inSubMenu :
        if selOpt=="" or not selOpt.isnumeric():
            inMenu = True
            continue;
        else:
            if type(kernelOpts[ optIndex[inMenu] ]['option'])==type([]):
                kernelOpts[ optIndex[inMenu] ]['value'] = kernelOpts[ optIndex[inMenu] ]['option'][ int(selOpt) ]
            else:
                if selOptType == "int":
                    kernelOpts[ optIndex[inMenu] ]["value"] = int(selOpt)
                else:
                    kernelOpts[ optIndex[inMenu] ]['value']=selOpt
            continue;
    if " " in selOpt:
        selOpt = selOpt.split(" ")
        selOpt = selOpt[0]
        selMod = selOpt[1]
    if selOpt.isnumeric() and int(selOpt)<len(kernelOpts):
        selOpt = int(selOpt)
        selOptName = kernelOpts[selOpt]["name"]
        selOptValue = kernelOpts[selOpt]["value"]
        selOptType = kernelOpts[selOpt]["option"]
        selOptHelp = kernelOpts[selOpt]["help"]
        if selOptType == "bool":
            kernelOpts[selOpt]["value"] = not kernelOpts[selOpt]["value"]
            continue;
        if selOptName == "_createKernel" :
            inMenu=False
            continue;
        elif selOptName == "_help" :
            kernelOpts[selOpt]["value"] = True
            continue;
        elif selOptName == "_exit" :
            inMenu=False
            isExit=True
            continue;
        inMenu = selOptName
    if selOpt == "" :
        selOpt = input("Create Kernel ? :")
        if not ( selOpt.lower() == "n" or selOpt.lower() == "no" ) :
            inMenu=False
            continue;



print("--")
if isExit:
    exit()

normalizeWeights = True
centralDistBased = False

multBasedWeight = True
multMin = 0.0
multMax = 4.0


#random.randint(0,1000000)%10


def print2dFloatArray( curArray, xRun = 0, separator = ", ", lineBreak = "\\\n" ):
    if not str(xRun).isnumeric():
        error( "Array X Sized is not numeric, please pass a number" )
    if xRun == 0 :
        print( curArray )
    else:
        #xRun += 1
        curPrint=""
        for c in range( len(curArray) ):
            if c == len(curArray)-1 :
                curPrint
                continue;
                
            # - Expand any Scientific Notated floats
            # - Get more than the default 18 max decimal precision
            # - Strip end '0's for values under 32bit precision
            #     6.365375029873694e-6 -> 0.00000636537502987369468998579691
            #     1.73378515243530273437500000000000 -> 1.733785152435302734375
            curPrint += re.sub(r'0+$',"", '{:.32f}'.format( curArray[ c ] )) + separator 
            
            if c%xRun == (xRun-1) :
                curPrint += lineBreak
        print( curPrint )


curKernel = [ 0.0 ]*(runX*runY+1)

minWeight = multMax if multBasedWeight else 1.0
maxWeight = multMin if multBasedWeight else 0.0
totalWeight = 0.0
derivWeight = 0.0

for c in range(len( curKernel )):
    curWeight = 0.0
    x = c%runX
    y = int(c/runX)
    if centralDistBased :
        curWeight = ( ((x-runX*.5+1)**2 + (y-runY*.5+1)**2) ** 0.5 )
    else:
        curWeight = random.random()
    #print( curWeight )
    
    #print( x, y )
    if multBasedWeight :
        curWeight = (curWeight*abs(multMax)*100000000.2545) % (multMax-multMin) 
    else:
        pass;
    minWeight = min( minWeight, curWeight )
    maxWeight = max( maxWeight, curWeight )
    totalWeight += curWeight
    curKernel[ c ] = curWeight

derivWeight = 1.0 / totalWeight

normalizedKernel = list(map( lambda x: (x-minWeight) / (maxWeight-minWeight) , curKernel ))
if normalizeWeights:
    normalizedKernel = list(map( lambda x: x*derivWeight , curKernel ))

print("  Multiplicative Kernel - ")
print2dFloatArray( curKernel, runX )
print("-- -- --")
if kernelOpts[optIndex["genNormalized"]]["value"]:
    print("  Normalized Kernel - ")
    print2dFloatArray( normalizedKernel, runX )
    print("  Normalized Kernel Total Weight Verification - ")
    print(ft.reduce( lambda x,c: x+c, normalizedKernel))
    print("-- -- --")

print( "Total Weight : ", totalWeight )
print( "Normalization Derivitive : ", derivWeight )

