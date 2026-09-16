{{/*
Вспомогательные шаблоны (named templates).

ЗАЧЕМ ЭТОТ ФАЙЛ НУЖЕН
Здесь описываются переиспользуемые куски, которые подставляются в другие
шаблоны через include. Имя чарта, полное имя релиза, набор меток — всё это
повторяется в каждом объекте, и держать это в одном месте гораздо надёжнее,
чем копировать по файлам. Поменяли схему меток — поменяли в одном месте.

ПОЧЕМУ ИМЯ НАЧИНАЕТСЯ С ПОДЧЁРКИВАНИЯ
Файлы, имя которых начинается с _, не превращаются в манифесты. Этот файл
содержит только определения и в кластер не попадает.

ЧЕМ INCLUDE ОТЛИЧАЕТСЯ ОТ TEMPLATE
Обе функции подставляют шаблон, но include возвращает строку, поэтому
её можно передать в nindent или indent. template просто печатает результат
на месте. В современном Helm используют include — иначе отступы не задать.
*/}}

{{/*
Имя чарта, при необходимости переопределяемое через values.
*/}}
{{- define "k8sphp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Полное имя релиза. Из него строятся имена ВСЕХ объектов чарта.

Логика такая же, как в стандартном шаблоне helm create:
  * если задан fullnameOverride — берём его;
  * если имя релиза уже содержит имя чарта (например, релиз называется
    web-k8sphp) — не дублируем и берём имя релиза;
  * иначе склеиваем «имя релиза — имя чарта».
Обрезка до 63 символов нужна потому, что имена объектов Kubernetes —
это DNS-метки с ограничением длины.
*/}}
{{- define "k8sphp.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Общие метки: применяются ко всем объектам чарта.
Такая схема (app.kubernetes.io/*) — общепринятая рекомендация Kubernetes,
её понимают инструменты вроде kube-state-metrics и большинство дашбордов.
*/}}
{{- define "k8sphp.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "k8sphp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Метки селектора — самое важное определение в этом файле, и вот почему.

Эти метки попадают в spec.selector.matchLabels у Deployment. А селектор
в Deployment НЕИЗМЕНЯЕМ: его нельзя поменять после создания объекта.
Если включить в селектор версию чарта, то при обновлении чарта селектор
изменится, и Kubernetes ответит:

    field is immutable

Релиз сломается, и починить его можно будет только удалением Deployment.

Поэтому действует правило: в selectorLabels входят ТОЛЬКО те метки,
которые никогда не меняются от релиза к релизу — имя и имя экземпляра.
Версия чарта, версия приложения и всё остальное живут в общих labels,
но НЕ в селекторе.
*/}}
{{- define "k8sphp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8sphp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
