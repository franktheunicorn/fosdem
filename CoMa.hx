import parsing.LstParser;
import util.Pair;
import interfaces.Printer;
import util.StdOutPrinter;
import util.NullPrinter;

/*
Input of CoMa

List of Individual-Name-String tab SequenceId pairs

First step, get all names
*/
class CoMa {
    public static function cToCol(v:Float, maxV:Float, minV:Float):String {
        var divVal:Float = (maxV != minV) ? maxV - minV : 0.01;
        var h:Float = ((360.0 - 120.0) - ((v - minV) / divVal * - 120.0)) % 360;
        var s:Float = 0.5, l:Float = 0.5;
        var r:Float = -1, g:Float = -1, b:Float = -1;
        var c:Float = (1 - Math.abs((l * 2) - 1)) * s;
        var h_:Float = h / 60;
        var x:Float = c * (1 - Math.abs((h_ % 2) - 1));
        var m:Float = l - (c / 2);
        if(0 <= h_ && h_ <= 1) {
            r = c;
            g = x;
            b = 0;
        } else if(1 <= h_ && h_ <= 2) {
            r = x;
            g = c;
            b = 0;
        } else if(2 <= h_ && h_ <= 3) {
            r = 0;
            g = c;
            b = x;
        } else if(3 <= h_ && h_ <= 4) {
            r = 0;
            g = x;
            b = c;
        } else if(4 <= h_ && h_ <= 5) {
            r = x;
            g = 0;
            b = c;
        } else if(5 <= h_ && h_ <= 6) {
            r = c;
            g = 0;
            b = x;
        }
        r = (r + m) * 256;
        g = (g + m) * 256;
        b = (b + m) * 256;
        return "rgb(" + Std.int(r) + "," + Std.int(g) + "," + Std.int(b) + ")";
    }

    public static function runComaJS(a:Array<String>, printer:Printer, printer2:Printer, printer3:Printer, namesOfMarkerFiles:Array<String>, runComaFromPartition:Int):Void {
        var l:List<List<Pair<String, String>>> = new List<List<Pair<String, String>>>();
        for(i in 0...a.length) {
            l.add(LstParser.parseLst(a[i]));
        }
        runComa(l, printer, printer2, printer3, namesOfMarkerFiles, runComaFromPartition);
    }

    // printer3: partitions
    public static function runComa(l:List<List<Pair<String, String>>>, printer:Printer, printer2:Printer, printer3:Printer, namesOfMarkerFiles:Array<String>, compStrategy:Int):Void {
        // 1. Step Table
        var comaIndL:List<CoMaInd> = new List<CoMaInd>();
        var index:Int = 0;
        for(lp in l) {
            for(p in lp) {
                var found:Bool = false;
                for(comaInd in comaIndL) {
                    if(comaInd.indName == p.first) {
                        comaInd.setSpResultOf(index, Std.parseInt(p.second));
                        found = true;
                        break;
                    }
                }
                if(!found) {
                    var newCoMaInd:CoMaInd = new CoMaInd(p.first, l.length);
                    newCoMaInd.setSpResultOf(index, Std.parseInt(p.second));
                    comaIndL.add(newCoMaInd);
                }
            }
            index++;
        }
        printer3.printString("Individual");
        for(i in 0...comaIndL.first().vals.length) {
            printer3.printString("\t");
            printer3.printString(namesOfMarkerFiles[i]);
        }
        printer3.printString("\n");
        for(ind in comaIndL) {
            printer3.printString(ind.indName);
            for(val in ind.vals) {
                printer3.printString("\t" + val);
            }
            printer3.printString("\n");
        }
        printer3.close();
        runComaFromPartition(new Pair<List<CoMaInd>, Null<Array<Int>>>(comaIndL, null), printer, printer2, compStrategy);
    }
    public static function runComaFromPartition(comaIndLP:Pair<List<CoMaInd>, Null<Array<Int>>>, printer:Printer, printer2:Printer, compStrategy:Int):Void {
        // xxx
        var comaIndL:List<CoMaInd> = comaIndLP.first;
        var weights:Null<Array<Int>> = comaIndLP.second;
        // 2. Step Cluster
        var orderedL:List<CoMaInd> = new List<CoMaInd>();
        var highestVal:Float = Math.NEGATIVE_INFINITY;
        var lowestVal:Float = Math.POSITIVE_INFINITY;
        if(compStrategy < -1) {
            compStrategy = compStrategy + 5;
            orderedL = comaIndL;
            for(e1 in orderedL) {
                for(e2 in orderedL) {
                    var dist:Float = e1.compare(e2, weights, compStrategy);
                    highestVal = Math.max(highestVal, dist);
                    lowestVal = Math.min(lowestVal, dist);
                }
            }
        } else {
            if(comaIndL.length == 0) {
                highestVal = 0;
                lowestVal = 0;
            } else if(comaIndL.length == 1) {
                orderedL.add(comaIndL.pop());
                highestVal = 0;
                lowestVal = 0;
            } else if(comaIndL.length == 2) {
                orderedL.add(comaIndL.pop());
                orderedL.add(comaIndL.pop());
                highestVal = orderedL.first().compare(orderedL.last(), weights, compStrategy);
                lowestVal = highestVal;
            } else {
                // get the pair of elements that is nearest
                var bestDist:Float = Math.NEGATIVE_INFINITY;
                var bestE1:CoMaInd = null;
                var bestE2:CoMaInd = null;
                for(e1 in comaIndL) {
                    for(e2 in comaIndL) {
                        var dist:Float = e1.compare(e2, weights, compStrategy);
                        if(e1 != e2) {
                            if(dist > bestDist) {
                                bestDist = dist;
                                bestE1 = e1;
                                bestE2 = e2;
                            }
                        }
                        highestVal = Math.max(highestVal, dist);
                        lowestVal = Math.min(lowestVal, dist);
                    }
                }
                comaIndL.remove(bestE1);
                comaIndL.remove(bestE2);
                orderedL.add(bestE1);
                orderedL.add(bestE2);
                // go on
                while(!comaIndL.isEmpty()) {
                    var bestDistFirst:Float = Math.NEGATIVE_INFINITY;
                    var bestDistLast:Float = Math.NEGATIVE_INFINITY;
                    var bestEFirst:CoMaInd = null;
                    var bestELast:CoMaInd = null;
                    for(e in comaIndL) {
                        var distFirst:Float = e.compare(orderedL.first(), weights, compStrategy);
                        var distLast:Float = e.compare(orderedL.last(), weights, compStrategy);
                        if(distFirst > bestDistFirst) {
                            bestDistFirst = distFirst;
                            bestEFirst = e;
                        }
                        if(distLast > bestDistLast) {
                            bestDistLast = distLast;
                            bestELast = e;
                        }
                    }
                    if(bestDistFirst > bestDistLast) {
                        comaIndL.remove(bestEFirst);
                        orderedL.push(bestEFirst); // to the beginning
                    } else {
                        comaIndL.remove(bestELast);
                        orderedL.add(bestELast); // to the end
                    }
                }
            }
        }
        // 3. Step Output Table
        for(e in orderedL) {
            printer2.printString("\t" + e.indName);
        }
        printer2.printString("\n");
        for(e1 in orderedL) {
            printer2.printString(e1.indName);
            for(e2 in orderedL) {
                var dist:Float = e1.compare(e2, weights, compStrategy);
                printer2.printString("\t" + dist);
            }
            printer2.printString("\n");
        }
        // 4. Step Output SVG
        var width:Float = 100 + orderedL.length * 20 + 5;
        var height:Float = 100 + orderedL.length * 20 + 5;
        printer.printString("<svg version=\"1.1\" baseProfile=\"full\" width=\"" + width + "\" height=\"" + height + "\" xmlns=\"http://www.w3.org/2000/svg\">");
        // labels
        printer.printString("<g style=\"font-family:serif;font-size:16\">");
        var index:Int = 0;
        for(e in orderedL) {
            printer.printString("<text x=\"5\" y=\"" + (100 + 20 * index + 15) + "\">" + e.indName + "</text>");
            printer.printString("<text x=\"" + (100 + 20 * index + 15) + "\" y=\"5\" transform=\"rotate(90 " + (100 + 20 * index + 7) + " 5)\">" + e.indName + "</text>");
            index++;
        }
        printer.printString("</g>");
        // labels end
        // matrix
        var i:Int = 0;
        var j:Int = 0;
        for(e1 in orderedL) {
            for(e2 in orderedL) {
                var dist:Float = e1.compare(e2, weights, compStrategy);
                printer.printString("<rect x=\"" + (100 + 20 * i) + "\" y=\"" + (100 + 20 * j) + "\" width=\"20\" height=\"20\" fill=\"" + cToCol(dist, highestVal, lowestVal) + "\"/>");
                j++;
            }
            j=0;
            i++;
        }
        // end matrix
        printer.printString("</svg>");
        printer.close();
        printer2.close();
    }

    public static function parsePartitionFile(fileContent:String):Pair<List<CoMaInd>, Null<Array<Int>>> {
        var comaIndL:List<CoMaInd> = new List<CoMaInd>();
        var lines:Array<String> = StringTools.rtrim(fileContent).split("\n");
        var lineNo:Int = 0;
        var weightLine:Array<Int> = null;
        for(line in lines) {
            lineNo++;
            var parts:Array<String> = line.split("\t");
            if(line == null || line == "" || (lineNo == 1)) {
                continue;
            }
            if(lineNo == lines.length && (parts[0] == "" || parts[0] == null)) {
                weightLine = new Array<Int>();
                for(index in 1...parts.length) {
                    weightLine.push(Std.parseInt(parts[index]));
                }
                continue;
            }
            var newCoMaInd:CoMaInd = new CoMaInd(parts[0], parts.length-1);
            for(index in 1...parts.length) {
                newCoMaInd.setSpResultOf(index-1, Std.parseInt(parts[index]));
            }
            comaIndL.add(newCoMaInd);
        }
        return new Pair<List<CoMaInd>, Null<Array<Int>>>(comaIndL, weightLine);
    }

    public static function main():Void {
#if sys
        var myArgs:Array<String> = Sys.args();
        if(myArgs.length == 0) {
            trace("Please specify at least one file");
        } else if(myArgs.length == 1) {
            var fileContent = sys.io.File.getContent(myArgs[0]);
            var comaIndL:Pair<List<CoMaInd>, Null<Array<Int>>> = parsePartitionFile(fileContent);
            var printer2:NullPrinter = new NullPrinter();
            var printer:StdOutPrinter = new StdOutPrinter();
            runComaFromPartition(comaIndL, printer, printer2, 0);
        } else {
            var l:List<List<Pair<String, String>>> = new List<List<Pair<String, String>>>();
            var namesOfMarkerFiles:Array<String> = new Array<String>();
            for(i in 0...myArgs.length) {
                var fileContent:String = sys.io.File.getContent(myArgs[i]);
                var listOfPairs:List<Pair<String, String>> = new List<Pair<String, String>>();
                var lines:Array<String> = fileContent.split("\n");
                var lineNo:Int = 0;
                for(line in lines) {
                    lineNo++;
                    var parts:Array<String> = line.split("\t");
                    if(line == null || line == "") {
                        continue;
                    }
                    listOfPairs.add(new Pair(parts[0], parts[1]));
                }
                l.add(listOfPairs);
                namesOfMarkerFiles.push(""); // not taken into account anyway (till now at least - printer3 is a NullPrinter). Implement a basename function and replace with basename(myArgs[i]) if needed
            }
            var printer2:NullPrinter = new NullPrinter();
            var printer3:NullPrinter = new NullPrinter();
            var printer:StdOutPrinter = new StdOutPrinter();
            runComa(l, printer, printer2, printer3, namesOfMarkerFiles, 0);
        }
#end
    }
}
