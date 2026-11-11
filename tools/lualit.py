"""Tiny Lua literal parser: tables, strings, numbers, nil/true/false, dotted names, + and unary -.
Unknown names resolve through `env` (dict of dotted name -> value), else None. Function calls -> None."""
import re
TOK = re.compile(r'''\s+|--\[\[.*?\]\]|--[^\n]*|(\[\[.*?\]\])|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?)|([A-Za-z_][\w]*(?:\.[A-Za-z_]\w*)*)|(\.\.|[{}\[\]=,;+\-*()#:])''', re.S)
def tokenize(s):
    out=[]; i=0; n=len(s)
    while i<n:
        m=TOK.match(s,i)
        if not m: raise ValueError('bad char %r at %d'%(s[i],i))
        i=m.end()
        if m.group(1): out.append(('s',m.group(1)[2:-2]))
        elif m.group(2):
            raw=m.group(2)[1:-1]
            out.append(('s',re.sub(r'\\(.)',lambda x:{'n':'\n','t':'\t'}.get(x.group(1),x.group(1)),raw)))
        elif m.group(3): out.append(('n',int(m.group(3),16) if m.group(3).startswith('0x') else (float(m.group(3)) if ('.' in m.group(3) or 'e' in m.group(3).lower()) else int(m.group(3)))))
        elif m.group(4): out.append(('id',m.group(4)))
        elif m.group(5): out.append(('p',m.group(5)))
    return out
class P:
    def __init__(s,toks,env): s.t=toks; s.i=0; s.env=env
    def peek(s,k=0): return s.t[s.i+k] if s.i+k<len(s.t) else ('eof',None)
    def next(s): tok=s.t[s.i]; s.i+=1; return tok
    def expect(s,v):
        tok=s.next()
        if tok[1]!=v: raise ValueError('expected %s got %r at %d'%(v,tok,s.i))
    def expr(s):
        v=s.term()
        while s.peek()[1] in ('+','-','*','..'):
            op=s.next()[1]; w=s.term()
            try:
                if op=='+': v=(v or 0)+(w or 0)
                elif op=='-': v=(v or 0)-(w or 0)
                elif op=='*': v=(v or 0)*(w or 0)
                else: v=str(v)+str(w)
            except Exception: v=None
        return v
    def term(s):
        k,v=s.next()
        if k=='s' or k=='n': return v
        if k=='p' and v=='-': x=s.term(); return -x if isinstance(x,(int,float)) else None
        if k=='p' and v=='{': return s.table()
        if k=='p' and v=='(':
            x=s.expr(); s.expect(')'); return x
        if k=='id':
            if v=='nil': return None
            if v=='true': return True
            if v=='false': return False
            val=s.env.get(v)
            # call or index
            while s.peek()[1] in ('(',':','['):
                if s.peek()[1]=='[': break
                if s.peek()[1]==':': s.next(); s.next()
                s.expect('('); depth=1
                while depth:
                    t=s.next()[1]
                    if t=='(': depth+=1
                    elif t==')': depth-=1
                val=None
            return val
        if k=='p' and v=='#': s.term(); return None
        raise ValueError('unexpected %r at %d'%((k,v),s.i))
    def table(s):
        arr=[]; d={}; idx=1; has_d=False
        while True:
            if s.peek()[1]=='}': s.next(); break
            if s.peek()[1]=='[':
                s.next(); key=s.expr(); s.expect(']'); s.expect('='); d[key]=s.expr(); has_d=True
            elif s.peek()[0]=='id' and s.peek(1)[1]=='=':
                key=s.next()[1]; s.next(); d[key]=s.expr(); has_d=True
            else:
                d[idx]=s.expr(); idx+=1
            if s.peek()[1] in (',',';'): s.next()
        return d
def parse_table_at(src, pos, env):
    """parse the table literal starting at the '{' at or after pos"""
    start=src.index('{',pos)
    toks=tokenize(src[start:])
    p=P(toks,env); p.expect('{'); return p.table()
def arr(t):
    """lua table dict with 1..n keys -> list (missing = None)"""
    if not isinstance(t,dict): return t
    n=max([k for k in t if isinstance(k,int)] or [0])
    return [t.get(i) for i in range(1,n+1)]
