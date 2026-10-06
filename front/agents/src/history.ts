import { Component, input, signal, inject, OnChanges } from '@angular/core';
import { DatePipe } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { History, statusLabels, errorText } from '../../shared/models';
@Component({ selector:'bag-history', imports:[DatePipe], template:`<section class="panel"><div class="topline"><h2>Historique du bagage</h2><span class="badge">Traçabilité</span></div>@if(busy()){<p role="status">Chargement…</p>}@if(error()){<div class="alert" role="alert">{{error()}}</div>}<ol class="history">@for(event of events();track event.id){<li><div class="topline"><strong>{{event.ancienStatut?labels[event.ancienStatut]+' → ':''}}{{labels[event.nouveauStatut]}}</strong>@if(event.anomalie){<span class="badge perdu">Transition anormale</span>}</div><time>{{event.horodatage | date:'dd/MM/yyyy à HH:mm:ss'}}</time><small class="mono muted">Agent : {{event.agentId}}</small>@if(event.motif){<p>{{event.motif}}</p>}</li>}</ol></section>` })
export class BagHistory implements OnChanges {
  labels = statusLabels;
  bagId=input.required<string>(); revision=input(0); events=signal<History[]>([]); busy=signal(false); error=signal(''); private http=inject(HttpClient); private request=0;
  ngOnChanges(){void this.load();}
  async load(){const current=++this.request;this.events.set([]);this.busy.set(true);this.error.set('');try{const data=await firstValueFrom(this.http.get<History[]>(`/api/bagages/${this.bagId()}/historique`));if(current===this.request)this.events.set(data);}catch(e){if(current===this.request)this.error.set(errorText(e));}finally{if(current===this.request)this.busy.set(false);}}
}
