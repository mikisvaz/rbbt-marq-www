require 'rubygems'
require 'soap/wsdlDriver'
require 'base64'
require 'zlib'

server = SOAP::WSDLDriverFactory.new( "http://marq.dacya.ucm.es/MARQWS.wsdl").create_rpc_driver 

up_list, down_list = DATA.read.split(/^-+\s*$/).collect {|chunk| chunk.scan(/[^\s]+/) }
p up_list
job = server.match_organism('sgd', up_list, down_list, '')

while not server.done(job)
  status = server.status(job)
  last_message = server.messages(job).last
  puts "#{ status }: #{ last_message }"
  sleep 1
end

raise "Error in job #{server.messages(job).last}" if server.error(job)

results_yaml_gz = Base64.decode64(server.result(server.results(job).first))
results_yaml = Zlib::GzipReader.new(StringIO.new(results_yaml_gz))
File.open('results.yaml', 'w') {|f| f.write results_yaml}
results = YAML.load(results_yaml)

puts "--- Results"


def compare(a,b)
  case 
  when a[:pvalue] < b[:pvalue]
    -1 
  when a[:pvalue] > b[:pvalue]
    1 
  when a[:pvalue] == b[:pvalue]
    b[:score].abs <=> a[:score].abs
  end
end


pos  = [] 
neg  = []
null = []

results.sort {|a,b| compare(a[1],b[1]) }.each do |p|
  null << p if p[1][:score] == 0
  pos << p if p[1][:score] > 0
  neg << p if p[1][:score] < 0
end

puts
puts "Top 10 directly related signatures"
pos[0..9].each do |p|
  puts "- #{p[0]} (#{p[1][:pvalues]})"
end

puts
puts "Top 10 inversely related signatures"
neg[0..9].each do |p|
  puts "- #{p[0]} (#{p[1][:pvalues]})"
end

puts
puts "Job id: #{ job }"
puts
puts "You may investigate de results further at:"
puts "http://marq.dacya.ucm.es/#{ job }"

__END__

HSP12
YLR042C
RFX1
YPL088W
YHL010C
YHR087W
CRG1
DAL7
HAL1
SRL3
GPD1
PRM5
PRM10
PST1
FMP33
YLR194C
CTT1
SLT2
YLR040C
YKE4
DDR48
YLR414C
CWP1
YMR315W
PIR3
YPS3
YIL024C
YGL157W
SED1
GAT1
GRE3
YGR146C
OAZ1
NQM1
KTR2
SPI1
PCM1
STF2
PPX1
HMX1
MDN1
MSB3
CAK1
YCL049C
SIP18
PNS1
FIR1
SVS1
GPG1
DAN4
YNL058C
SYM1
SBE22
YET1
RBK1
CRH1
ALD4
PGM2
YDR262W
KRE11
MCH5
GRE2
NUP85
ECM4
SOL4
HOR2
TMA10
MSG5
YJL171C
YJR008W
YML131W
DFG5
PNC1
PRY2
CIS3
GDB1
RCR1
YOL019W
ORC6
SWC7
SPG5
PET10
ATG8
PEX27
YKL161C
ICT1
TFS1
GOR1
BGL2
DOG2
GFA1
IAH1
MSB4
DCS2
YJL160C
TIR2
SMF1
BZZ1
MSC1
FYV8
RGS2
EXG1
FAS2
CIT1
DUN1
YHR097C
YMR181C
SOR1
CHS7
RCN2
YEH1
ACA1
YNL194C
YML087C
GTT1
ECM13
YHR033W
DOG1
ENT3
THI22
MET28
YKL151C
ATP22
SOM1
FRE2
HXT1
YSP3
YPR1
SOL1
AGX1
FMP48
IML2
MID2
NCA3
YDL114W
YOL048C
YNR065C
SLU7
PTP2
YNL208W
YKL121W
VPS27
HXK1
MET16
HSP32
LSC2
YMR090W
SLD2
YIL108W
PRR1
GIC2
PRX1
ADD37
CMK2
YPL23HSP12
YLR042C
RFX1
YPL088W
YHL010C
YHR087W
CRG1
DAL7
HAL1
SRL3
GPD1
PRM5
PRM10
PST1
FMP33
YLR194C
CTT1
SLT2
YLR040C
YKE4
DDR48
YLR414C
CWP1
YMR315W
PIR3
YPS3
YIL024C
YGL157W
SED1
GAT1
GRE3
YGR146C
OAZ1
NQM1
KTR2
SPI1
PCM1
STF2
PPX1
HMX1
MDN1
MSB3
CAK1
YCL049C
SIP18
PNS1
FIR1
SVS1
GPG1
DAN4
YNL058C
SYM1
SBE22
YET1
RBK1
CRH1
ALD4
PGM2
YDR262W
KRE11
MCH5
GRE2
NUP85
ECM4
SOL4
HOR2
TMA10
MSG5
YJL171C
YJR008W
YML131W
DFG5
PNC1
PRY2
CIS3
GDB1
RCR1
YOL019W
ORC6
SWC7
SPG5
PET10
ATG8
PEX27
YKL161C
ICT1
TFS1
GOR1
BGL2
DOG2
GFA1
IAH1
MSB4
DCS2
YJL160C
TIR2
SMF1
BZZ1
MSC1
FYV8
RGS2
EXG1
FAS2
CIT1
DUN1
YHR097C
YMR181C
SOR1
CHS7
RCN2
YEH1
ACA1
YNL194C
YML087C
GTT1
ECM13
YHR033W
DOG1
ENT3
THI22
MET28
YKL151C
ATP22
SOM1
FRE2
HXT1
YSP3
YPR1
SOL1
AGX1
FMP48
IML2
MID2
NCA3
YDL114W
YOL048C
YNR065C
SLU7
PTP2
YNL208W
YKL121W
VPS27
HXK1
MET16
HSP32
LSC2
YMR090W
SLD2
YIL108W
PRR1
GIC2
PRX1
ADD37
CMK2
YPL230W
-----
NIP7
RAS1
BRX1
YIL064W
NSR1
TPN1
FET3
ILV5
DBP2
LIA1
PHO5
FCY2
OPT1
PHO11
ZRT2
SSU1
MRH1
SHM2
AAH1
ATO3
PHO3
YHB1
PHO12
LAP4
