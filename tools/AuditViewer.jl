isdefined(@__MODULE__, :ClosureAudit) || include("ClosureAudit.jl")

module AuditViewer

import ..ModelAudit
import ..BackgroundAudit
import ..ClosureAudit
using Base64
using JSON3
using TOML

_state_mask(state) = sum((state[i] ? 1 << (i-1) : 0) for i in eachindex(state))

const VIEWER_DESCRIPTIONS = Dict(
    "all_four" => "M2とDCの4条件が同時に成立する基準例。",
    "without_hSelf" => "K内のu3は二出力の同時停止で失われるが、単独介入由来のΦでは覆われない。",
    "without_hSMC" => "分岐時の入力u2が、最終点差分で入力へ戻る出力応答に含まれない。",
    "without_hAct" => "ρ*(K)とσ*(ε)は各々非空だが、異なる出力を選ぶため交差しない。",
    "without_hBound" => "properなKを持つが、Kから支持外への配線がない。",
    "all_dc_with_support_expansion" => "M2とDC全条件が成立する一方、観測KはνΦの真部分集合。",
    "symmetric_union" => "対称な二支持は個別に固定点だが、最大支持νΦはその合併になる。",
)

function _viewer_case(name, description, circuit, measured; origin)
    closure = ClosureAudit.check_observed_closure(measured.model)
    background = BackgroundAudit.check_adjunction_background(measured.model)
    n = length(circuit.units)
    masks = 0:((1 << n)-1)
    traces = [[_state_mask(state) for state in measured.traces[mask]] for mask in masks]
    baseline = ModelAudit._audit_persist(measured.traces[0],circuit.R,circuit.units)
    Dict{String,Any}(
        "name"=>name,"description"=>description,"origin"=>origin,
        "units"=>String.(collect(circuit.units)),"motors"=>String.(collect(circuit.motors)),
        "inputs"=>String.(collect(circuit.inputs)),"edges"=>collect.(collect(circuit.edges)),
        "thresholds"=>collect(circuit.thresholds),"initial"=>collect(circuit.initial),
        "P"=>circuit.P,"H"=>circuit.H,"L"=>circuit.L,"R"=>circuit.R,
        "kappa"=>ModelAudit._audit_names(measured.model.kappa),"future_Q"=>ModelAudit._audit_names(baseline),
        "nu_phi"=>ModelAudit._audit_names(closure.nu_phi),"phi_kappa"=>ModelAudit._audit_names(closure.phi_kappa),
        "dc"=>collect(measured.result.actual),"adjunction_holds"=>background.holds,
        "active_boundary"=>measured.active_boundary,"trace_masks"=>traces,
        "branch_count"=>length(traces),"all_interventions"=>measured.all_interventions,
        "kappa_equals_nu"=>closure.kappa_equals_nu,"kappa_subset_nu"=>closure.kappa_subset_nu,
    )
end

function audit_viewer_data()
    cases = Dict{String,Any}[]
    for witness in BackgroundAudit.adjoint_measured_witnesses()
        measured = ModelAudit.measure_circuit(witness.circuit)
        push!(cases,_viewer_case(witness.name,VIEWER_DESCRIPTIONS[witness.name],witness.circuit,measured;
            origin="explicit_P3_adjoint_witness"))
    end
    expanded_circuit = ClosureAudit._support_expansion_witness()
    push!(cases,_viewer_case("all_dc_with_support_expansion",VIEWER_DESCRIPTIONS["all_dc_with_support_expansion"],
        expanded_circuit,ModelAudit.measure_circuit(expanded_circuit);origin="modified_initial_P3"))
    union_path = normpath(joinpath(@__DIR__,"..","logs","gates","RSB-AUDIT-008","symmetric-union-witness.toml"))
    isfile(union_path) || throw(ArgumentError("missing symmetric-union witness"))
    union_data = TOML.parsefile(union_path)
    union_circuit = ModelAudit.parse_audit_circuit(union_data["measurement"]["circuit"])
    push!(cases,_viewer_case("symmetric_union",VIEWER_DESCRIPTIONS["symmetric_union"],union_circuit,
        ModelAudit.measure_circuit(union_circuit);origin="symmetric_union_fixture"))
    payload = Dict{String,Any}(
        "schema_version"=>1,"title"=>"ERIE-C 有限モデル監査ビューア",
        "phenomenal_claim"=>"not_certified","execution_certified"=>false,
        "coordinate_semantics"=>"diagram_only_not_physical_space_or_decomposition",
        "dc_scope"=>"whole_case_measurement_not_selected_branch_certification",
        "case_count"=>length(cases),"total_branch_count"=>sum(c["branch_count"] for c in cases),
        "cases"=>cases)
    payload["generation_digest"] = ModelAudit._audit_digest(payload)
    payload
end

function render_audit_viewer(data=audit_viewer_data())
    encoded = base64encode(String(JSON3.write(data)))
    """<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
<title>ERIE-C 有限モデル監査ビューア</title>
<style>
:root{color-scheme:dark;--bg:#0c111b;--panel:#141c2a;--line:#36445d;--ink:#e8eef9;--muted:#96a6bf;--on:#62db9a;--diff:#ffbd5b;--k:#60a5fa;--q:#a78bfa;--nu:#f472b6;--bad:#fb7185}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 15% 0,#17243a 0,var(--bg) 40%);color:var(--ink);font-family:ui-sans-serif,system-ui,"Noto Sans JP",sans-serif}main{max-width:1440px;margin:auto;padding:24px}.top{display:flex;justify-content:space-between;gap:24px;align-items:flex-start}.eyebrow{color:var(--on);letter-spacing:.12em;font-size:12px}.badge{border:1px solid var(--line);border-radius:999px;padding:7px 11px;color:var(--muted);font-size:12px}h1{margin:7px 0 8px;font-size:clamp(25px,4vw,42px)}p{color:var(--muted);line-height:1.65}.controls,.panel{background:color-mix(in srgb,var(--panel) 94%,transparent);border:1px solid var(--line);border-radius:15px;padding:16px}.controls{display:grid;grid-template-columns:minmax(220px,2fr) minmax(240px,3fr) 1fr;gap:16px;margin:20px 0}label{display:block;color:var(--muted);font-size:12px;margin-bottom:6px}select,input[type=range]{width:100%;accent-color:var(--on)}select{background:#0c1421;color:var(--ink);border:1px solid var(--line);border-radius:8px;padding:9px}.stop-grid{display:flex;flex-wrap:wrap;gap:7px}.stop-grid label{border:1px solid var(--line);border-radius:8px;padding:6px 8px;margin:0;color:var(--ink)}.grid{display:grid;grid-template-columns:minmax(560px,3fr) minmax(310px,1fr);gap:16px}.metrics{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;margin-bottom:16px}.metric{background:#0d1522;border:1px solid var(--line);border-radius:10px;padding:10px}.metric strong{display:block;margin-top:4px}.pass{color:var(--on)}.fail{color:var(--bad)}svg{width:100%;height:520px;background:#0a101a;border-radius:11px}.edge{stroke:#53627a;stroke-width:2}.edge.neg{stroke:var(--bad);stroke-dasharray:6 4}.edge-label{fill:var(--muted);font-size:11px}.node{stroke:#64748b;stroke-width:2;fill:#172033}.node.on{fill:#185d42;stroke:var(--on)}.node.diff{stroke:var(--diff);stroke-width:4}.node-label{fill:var(--ink);font-weight:700;text-anchor:middle;pointer-events:none}.role-label{fill:var(--muted);font-size:10px;text-anchor:middle;pointer-events:none}.set-ring{fill:none;stroke-width:3;stroke-dasharray:5 3}.set-k{stroke:var(--k)}.set-q{stroke:var(--q)}.set-nu{stroke:var(--nu)}.legend{display:flex;flex-wrap:wrap;gap:12px;font-size:12px;color:var(--muted);margin:10px 0}.swatch{display:inline-block;width:11px;height:11px;border:2px solid;margin-right:5px;border-radius:50%;vertical-align:-1px}.timeline{display:grid;gap:4px;overflow:auto}.timeline-row{display:grid;grid-template-columns:42px repeat(7,36px);gap:4px}.cell{height:27px;border:1px solid #26334a;border-radius:5px;background:#0b121e;text-align:center;font-size:10px;padding-top:5px}.cell.on{background:#185d42;border-color:var(--on)}.cell.now{outline:2px solid var(--diff)}.cell.diff{color:var(--diff)}.sets{display:grid;gap:10px}.set-card{border-left:3px solid var(--line);padding-left:10px}.set-card b{display:block}.small{font-size:12px}.warning{border-left:3px solid var(--diff);padding-left:12px;margin-top:14px}@media(max-width:950px){.controls,.grid{grid-template-columns:1fr}.metrics{grid-template-columns:repeat(2,1fr)}svg{height:430px}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto}}
</style></head><body><main>
<div class="top"><div><div class="eyebrow">FINITE MODEL AUDIT / LOCAL ARTIFACT</div><h1>介入・時間・支持を同じ画面で読む</h1><p id="description"></p></div><div class="badge">phenomenal_claim = not_certified</div></div>
<section class="controls"><div><label for="case">モデル</label><select id="case"></select></div><div><label>発信停止するユニット</label><div id="stops" class="stop-grid"></div></div><div><label for="time">分岐後時刻 t=<span id="timeValue">0</span></label><input id="time" type="range" min="0" value="0"></div></section>
<div id="metrics" class="metrics"></div>
<div class="grid"><section class="panel"><svg id="network" role="img" aria-label="回路図"></svg><div class="legend"><span><i class="swatch" style="border-color:var(--on)"></i>on</span><span><i class="swatch" style="border-color:var(--diff)"></i>自然対照との差</span><span><i class="swatch" style="border-color:var(--k)"></i>K</span><span><i class="swatch" style="border-color:var(--q)"></i>将来Q</span><span><i class="swatch" style="border-color:var(--nu)"></i>νΦ</span></div><div id="timeline" class="timeline"></div></section>
<aside class="panel"><div id="sets" class="sets"></div><p class="warning small">DC/M2はcase全体の測定値です。選択中のbranchだけの認証値ではありません。図の座標は表示用で、物理空間や分解Dを表しません。</p><p class="small">生成digest: <span id="digest"></span></p></aside></div>
</main><script>
'use strict';
const raw=atob('$encoded');const bytes=Uint8Array.from(raw,c=>c.charCodeAt(0));const audit=JSON.parse(new TextDecoder().decode(bytes));
const byId=id=>document.getElementById(id), svgNS='http://www.w3.org/2000/svg';let selectedMask=0;
function svg(tag,attrs={},text=''){const el=document.createElementNS(svgNS,tag);for(const [k,v] of Object.entries(attrs))el.setAttribute(k,String(v));if(text)el.textContent=text;return el}
function names(mask,c){return c.units.filter((_,i)=>mask&(1<<i))}function stateAt(c,mask,t){return c.trace_masks[mask][t]}function inSet(xs,u){return xs.includes(u)}
function setText(xs){return xs.length?xs.join(', '):'∅'}function role(c,u){return c.inputs.includes(u)?'input':c.motors.includes(u)?'motor':'internal'}
function renderStops(c){const host=byId('stops');host.replaceChildren();selectedMask=0;c.units.forEach((u,i)=>{const label=document.createElement('label'),box=document.createElement('input');box.type='checkbox';box.dataset.bit=String(i);box.addEventListener('change',()=>{selectedMask=0;host.querySelectorAll('input:checked').forEach(x=>selectedMask|=1<<Number(x.dataset.bit));render()});label.append(box,document.createTextNode(' '+u));host.append(label)})}
function renderMetrics(c){const labels=['hSelf','hSMC','hAct','hBound'];const rows=labels.map((name,i)=>[name,c.dc[i]]);rows.push(['M2',c.adjunction_holds]);const host=byId('metrics');host.replaceChildren();for(const [name,value] of rows){const d=document.createElement('div');d.className='metric';const s=document.createElement('span');s.textContent=name;const strong=document.createElement('strong');strong.className=value?'pass':'fail';strong.textContent=value?'TRUE':'FALSE';d.append(s,strong);host.append(d)}}
function renderNetwork(c,t){const host=byId('network');host.replaceChildren();const width=760,height=500,cx=width/2,cy=height/2,r=Math.min(width,height)*.34;host.setAttribute('viewBox',`0 0 \${width} \${height}`);const pts=c.units.map((_,i)=>[cx+r*Math.cos(2*Math.PI*i/c.units.length-Math.PI/2),cy+r*Math.sin(2*Math.PI*i/c.units.length-Math.PI/2)]);for(const [s,d,w] of c.edges){const [x1,y1]=pts[s-1],[x2,y2]=pts[d-1],dx=x2-x1,dy=y2-y1,len=Math.hypot(dx,dy),pad=31;host.append(svg('line',{x1:x1+dx/len*pad,y1:y1+dy/len*pad,x2:x2-dx/len*pad,y2:y2-dy/len*pad,class:w<0?'edge neg':'edge'}));host.append(svg('text',{x:(x1+x2)/2,y:(y1+y2)/2-5,class:'edge-label'},w>0?`+\${w}`:String(w)))}const state=stateAt(c,selectedMask,t),base=stateAt(c,0,t);c.units.forEach((u,i)=>{const [x,y]=pts[i];for(const [set,klass,rad] of [[c.nu_phi,'set-ring set-nu',34],[c.future_Q,'set-ring set-q',30],[c.kappa,'set-ring set-k',26]])if(inSet(set,u))host.append(svg('circle',{cx:x,cy:y,r:rad,class:klass}));const circle=svg('circle',{cx:x,cy:y,r:21,class:`node\${state&(1<<i)?' on':''}\${(state^base)&(1<<i)?' diff':''}`});host.append(circle);host.append(svg('text',{x,y:y+4,class:'node-label'},u));host.append(svg('text',{x,y:y+48,class:'role-label'},role(c,u)))})}
function renderTimeline(c,current){const host=byId('timeline');host.replaceChildren();const states=c.trace_masks[selectedMask],base=c.trace_masks[0];c.units.forEach((u,i)=>{const row=document.createElement('div');row.className='timeline-row';const name=document.createElement('b');name.textContent=u;row.append(name);states.forEach((state,t)=>{const cell=document.createElement('span');cell.className=`cell\${state&(1<<i)?' on':''}\${t===current?' now':''}\${(state^base[t])&(1<<i)?' diff':''}`;cell.textContent=String(t);cell.title=`\${u} t=\${t}: \${state&(1<<i)?'on':'off'}`;row.append(cell)});host.append(row)})}
function renderSets(c){const entries=[['停止集合',names(selectedMask,c),'#ffbd5b'],['分岐前の支持 K',c.kappa,'var(--k)'],['自然対照の将来 Q',c.future_Q,'var(--q)'],['最大不動点 νΦ',c.nu_phi,'var(--nu)'],['Φ(K)',c.phi_kappa,'#94a3b8']];const host=byId('sets');host.replaceChildren();for(const [title,xs,color] of entries){const d=document.createElement('div');d.className='set-card';d.style.borderColor=color;const b=document.createElement('b'),span=document.createElement('span');b.textContent=title;span.textContent=setText(xs);d.append(b,span);host.append(d)}const meta=document.createElement('p');meta.className='small';meta.textContent=`P/H/L/R=\${c.P}/\${c.H}/\${c.L}/\${c.R} · branches=\${c.branch_count} · K=νΦ: \${c.kappa_equals_nu}`;host.append(meta)}
function render(){const c=audit.cases[Number(byId('case').value)],t=Number(byId('time').value);byId('description').textContent=`\${c.description} 由来: \${c.origin}`;byId('timeValue').textContent=String(t);renderMetrics(c);renderNetwork(c,t);renderTimeline(c,t);renderSets(c)}
const select=byId('case');audit.cases.forEach((c,i)=>{const o=document.createElement('option');o.value=String(i);o.textContent=c.name;select.append(o)});select.addEventListener('change',()=>{const c=audit.cases[Number(select.value)];byId('time').max=String(c.H);byId('time').value='0';renderStops(c);render()});byId('time').addEventListener('input',render);byId('digest').textContent=audit.generation_digest;byId('time').max=String(audit.cases[0].H);renderStops(audit.cases[0]);render();
</script></body></html>"""
end

function write_audit_viewer(path::AbstractString)
    data = audit_viewer_data()
    open(path,"w") do io
        write(io,render_audit_viewer(data))
    end
    data
end

end
