from pathlib import Path
import hashlib,json,os,signal,subprocess,time

BASE=Path('/mnt/development/projects/diagnostics/otzaria-wave3-inspector-selection-20261127')
RUN=BASE/'controls-kit-attempt-1'
REPO=Path('/mnt/development/projects/worktrees/TorahInspectorKit-wave3-original-selection-20261127')
SWIFT=Path('/mnt/development/tooling/swiftly/toolchains/6.4.3/usr/bin/swiftc')
FLOOR=2*1024**3
BUDGET=300*1024**2
CORE={
 'Models.swift':'59a0c8639c8c778c67ff9c60db4b979e3ba7a39dff4c3fb669a54ae23dc113a0',
 'ProviderProtocols.swift':'9f5f28f1d71a97831827dce5dfe2324a60460fc7760137b9527e4c3815d20273',
 'TorahInspectorCoordinator.swift':'fccfc25ee56e165c6559aba52a1ccec39d10db6fd6a94a91c867cd38dc693116',
 'TorahInspectorRepository.swift':'519828f3d602811758d2698e00a06567b41d31d465b143175441f08873300040',
 'TorahReaderScrollStateMachine.swift':'90173f3198133c6a746d00c9a6af9ad8cd854f5643f924d98e9095133da5bbdc',
 'TorahRelatedDocumentsAccessError.swift':'0ff22bb5a56ddff0235e7b6c5188c737b110cb2848d7e17dcaefc3ca1d6df2e6',
 'TorahSourceTransfer.swift':'994da5da2cb6b163083c7f3dea20cfe74c781211eea0f144b394a6d047affc97',
 'TorahToolSelectorStateMachine.swift':'34dda44a571764ea98e43449422340ad7a00dbe4b0d43c0036d7d48ad8119729'}
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def usage():
 logical=allocated=0
 for parent,dirs,files in os.walk(BASE):
  for name in files:
   st=os.lstat(os.path.join(parent,name));logical+=st.st_size;allocated+=st.st_blocks*512
 return {'logical':logical,'allocated':allocated}
def free():
 st=os.statvfs(BASE);return st.f_bavail*st.f_frsize
def guard():
 u=usage();f=free()
 if f<FLOOR or u['allocated']>BUDGET:raise RuntimeError('owned capacity guard '+str({'free':f,'own':u}))
 return {'time':time.time(),'free':f,'own':u}
def write(name,data):
 guard();p=RUN/name
 with p.open('xb') as f:f.write(data);f.flush();os.fsync(f.fileno())
def jsonwrite(name,data):write(name,(json.dumps(data,indent=2,ensure_ascii=False)+'\n').encode())
RESULT={'scope':'Original eight-file Kit Core module, exact original navigation view methods/load lifetime plus candidate retention. Explicit storage/localization/layout boundary; no Apple SDK or native acceptance.', 'nativeRuns':0,'AppleSDK':'NOT_RUN','stages':[]}
def execute(label,argv,timeout):
 before=guard();env=dict(os.environ);env['TMPDIR']=str(RUN/'tmp')
 stdout=RUN/(label+'.stdout');stderr=RUN/(label+'.stderr')
 with stdout.open('xb') as out,stderr.open('xb') as err:
  start=time.monotonic();process=subprocess.Popen(argv,stdout=out,stderr=err,env=env,start_new_session=True)
  identity={'pid':process.pid,'pgid':os.getpgid(process.pid),'procStart':Path('/proc/'+str(process.pid)+'/stat').read_text().split()[21]}
  jsonwrite(label+'.PROCESS.json',{'argv':argv,**identity,'before':before})
  stopped=None;samples=[]
  while process.poll() is None:
   try:samples.append(guard())
   except Exception as exc:stopped=str(exc)
   if time.monotonic()-start>timeout:stopped='owned component timeout'
   if stopped:
    if process.poll() is None:os.killpg(process.pid,signal.SIGTERM)
    try:process.wait(timeout=10)
    except subprocess.TimeoutExpired:
     if process.poll() is None:os.killpg(process.pid,signal.SIGKILL)
     process.wait()
    break
   time.sleep(0.5)
  code=process.wait();out.flush();err.flush()
 record={'label':label,'argv':argv,'returncode':code,'seconds':time.monotonic()-start,'capacityStop':stopped,
  'stdout':{'bytes':stdout.stat().st_size,'sha256':digest(stdout)},'stderr':{'bytes':stderr.stat().st_size,'sha256':digest(stderr)},
  'minimumFree':min([before['free']]+[x['free'] for x in samples]),'peakOwnAllocated':max([before['own']['allocated']]+[x['own']['allocated'] for x in samples]),'after':guard()}
 RESULT['stages'].append(record);jsonwrite(label+'.RESULT.json',record)
 if code or stopped:raise RuntimeError(label+' failed '+str(code)+' '+str(stopped))
 return record

try:
 RESULT['initial']=guard()
 assert subprocess.check_output(['runuser','-u','ubuntu','--','git','-C',str(REPO),'rev-parse','HEAD'],text=True).strip()=='26beca175d64a4d34e3567f2bbb4bf308d714478'
 assert not subprocess.check_output(['runuser','-u','ubuntu','--','git','-C',str(REPO),'status','--porcelain','--untracked-files=no'],text=True).strip()
 for name in ['core','output','tmp','module-cache']:(RUN/name).mkdir(exist_ok=False)
 inputs=[]
 for name,expected in CORE.items():
  original=REPO/'Sources/TorahInspectorCore'/name;assert digest(original)==expected
  b=original.read_bytes();write('core/'+name,b);inputs.append({'origin':str(original),'bytes':len(b),'sha256':expected})
 for p in sorted((RUN/'input').glob('*.swift')):inputs.append({'input':str(p),'bytes':p.stat().st_size,'sha256':digest(p)})
 jsonwrite('COMPILED_INPUTS.json',{'inputs':inputs,'compiler':str(SWIFT),'compilerSHA256':digest(SWIFT),'initial':RESULT['initial']})
 common=[str(SWIFT),'-swift-version','6','-strict-concurrency=complete','-parse-as-library','-module-cache-path',str(RUN/'module-cache')]
 execute('core-compile',common+['-emit-module','-emit-library','-module-name','TorahInspectorCore','-emit-module-path',str(RUN/'output/TorahInspectorCore.swiftmodule')]+[str(RUN/'core'/x) for x in CORE]+['-o',str(RUN/'output/libTorahInspectorCore.so')],180)
 execute('controls-compile',common+['-I',str(RUN/'output'),'-L',str(RUN/'output'),'-lTorahInspectorCore','-Xlinker','-rpath','-Xlinker',str(RUN/'output')]+[str(p) for p in sorted((RUN/'input').glob('*.swift'))]+['-o',str(RUN/'output/kit-controls')],180)
 execute('controls-run',[str(RUN/'output/kit-controls')],60)
 RESULT['controls']=json.loads((RUN/'controls-run.stdout').read_text())
 RESULT['status']='COMPONENT_CONTROLS_COMPLETED'
except Exception as exc:RESULT['status']='FAILED';RESULT['error']=repr(exc)
finally:
 RESULT['final']={'free':free(),'own':usage()}
 # Tiny durable failure receipt remains necessary even when a sampled capacity guard stopped the child.
 p=RUN/'RESULT.json'
 with p.open('x') as f:json.dump(RESULT,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 print(json.dumps({'path':str(p),'sha256':digest(p),'result':RESULT}))
