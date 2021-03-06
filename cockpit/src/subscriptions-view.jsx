/*
 * This file is part of Cockpit.
 *
 * Copyright (C) 2016 Red Hat, Inc.
 *
 * Cockpit is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * Cockpit is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Cockpit; If not, see <http://www.gnu.org/licenses/>.
 */

var cockpit = require("cockpit");
var _ = cockpit.gettext;

var React = require("react");

import subscriptionsClient from './subscriptions-client';
import { ListView, ListViewItem, ListViewIcon } from 'patternfly-react';
import { Row, Col } from 'react-bootstrap';

class Listing extends React.Component {
    render() {
        if (this.props.children) {
            return (
                <div>
                    <h2>{this.props.title}</h2>
                    {this.props.children}
                </div>
            );
        } else {
            return (
                <div>
                    <h2>{this.props.emptyCaption}</h2>
                </div>
            );
        }
    }
}

/* 'Curtains' implements a subset of the PatternFly Empty State pattern
 * https://www.patternfly.org/patterns/empty-state/
 * Special values for icon property:
 *   - 'waiting' - display spinner
 *   - 'error'   - display error icon
 */
var Curtains = React.createClass({
    render: function() {
        var description = null;
        if (this.props.description)
            description = <h1>{this.props.description}</h1>;

        var message = null;
        if (this.props.message)
            message = <p>{this.props.message}</p>;

        var curtains = "curtains-ct";

        var icon = this.props.icon;
        if (icon === 'waiting')
            icon = <div className="spinner spinner-lg"></div>;
        else if (icon === 'error')
            icon = <div className="pficon pficon-error-circle-o"></div>;

        return (
            <div className={ curtains + " blank-slate-pf" }>
                <div className="blank-slate-pf-icon">
                    {icon}
                </div>
                {description}
                {message}
            </div>
        );
    }
});

/* Component to show a dismissable error, message as child text
 * dismissError callback function triggered when the close button is pressed
 */
var DismissableError = React.createClass({
    handleDismissError: function(e) {
        // only consider primary mouse button
        if (!e || e.button !== 0)
            return;
        if (this.props.dismissError)
            this.props.dismissError();
        e.stopPropagation();
    },
    render: function() {
        return (
            <div className="alert alert-danger alert-dismissable alert-ct-top">
                <span className="pficon pficon-error-circle-o" />
                <span>{this.props.children}</span>
                <button type="button" className="close" aria-hidden="true" onClick={this.handleDismissError}>
                    <span className="pficon pficon-close"/>
                </button>
            </div>
        );
    }
});

/* Show subscriptions status of the system, offer to register/unregister the system
 * Expected properties:
 * status        subscription status
 * error        error message to show (in Curtains if not connected, as a dismissable alert otherwise
 * dismissError callback, triggered for the dismissable error in connected state
 * register     callback, triggered when user clicks on register
 * unregister   callback, triggered when user clicks on unregister
 */
var SubscriptionStatus = React.createClass({
    handleRegisterSystem: function(e) {
        // only consider primary mouse button
        if (!e || e.button !== 0)
            return;
        this.props.register();
        e.stopPropagation();
    },
    handleUnregisterSystem: function(e) {
        // only consider primary mouse button
        if (!e || e.button !== 0)
            return;
        this.props.unregister();
        e.stopPropagation();
    },
    render: function() {
        var errorMessage;
        if (this.props.error) {
            errorMessage = (
                <DismissableError dismissError={this.props.dismissError}>{String(this.props.error)}</DismissableError>
            );
        }

        var label;
        var action;
        var note;
        var isUnregistering = (this.props.status === "unregistering");
        if (this.props.status === 'Unknown') {
            label = <label>{ cockpit.format(_("Status: $0"), _("This system is currently not registered.")) }</label>;
            action = (<button className="btn btn-primary"
                              onClick={this.handleRegisterSystem}>{_("Register")}</button>
            );
        } else {
            label = <label>{ cockpit.format(_("Status: $0"), this.props.status) }</label>;
            action = (<button className="btn btn-primary" disabled={isUnregistering}
                              onClick={this.handleUnregisterSystem}>{_("Unregister")}</button>
            );
            if (isUnregistering) {
                note = (
                    <div className="dialog-wait-ct">
                        <div className="spinner spinner-sm"></div>
                        <span>{ _("Unregistering") }</span>
                    </div>
                );
            }
        }
        return (
            <div className="subscription-status-ct">
                <h2>{_("Subscriptions")}</h2>
                {errorMessage}
                {label}
                {action}
                {note}
            </div>
        );
    }
});

/* Show subscriptions status of the system and registered products, offer to register/unregister the system
 * Expected properties:
 * status       subscription status
 * error        error message to show (in Curtains if not connected, as a dismissable alert otherwise
 * dismissError callback, triggered for the dismissable error in connected state
 * products     subscribed products (properties as in subscriptions-client)
 * register     callback, triggered when user clicks on register
 * unregister   callback, triggered when user clicks on unregister
 */
var SubscriptionsPage = React.createClass({
    renderCurtains: function() {
        var icon;
        var description;
        var message;
        if (this.props.status === undefined || !subscriptionsClient.config.loaded) {
            icon = <div className="spinner spinner-lg" />;
            message = _("Updating");
            description = _("Retrieving subscription status...");
        } else if (this.props.status === 'access-denied') {
            icon = <i className="fa fa-exclamation-circle" />;
            message = _("Access denied");
            description = _("The current user isn't allowed to access system subscription status.");
        } else {
            icon = <i className="fa fa-exclamation-circle" />;
            message = _("Unable to connect");
            description = _("Couldn't get system subscription status. Please ensure subscription-manager is installed.");
        }
        return (
            <Curtains
                icon={icon}
                description={description}
                message={message} />
        );
    },
    renderSubscriptions: function() {
        var entries = this.props.products.map(function (itm) {
            let icon_name;
            let status_text;

            if (itm.status === 'subscribed') {
                icon_name = "fa pficon-ok";
            } else {
                icon_name = "fa pficon-error-circle-o";
            }

            if (itm.status === 'subscribed') {
                status_text = _("Subscribed");
            } else {
                status_text = _("Not Subscribed (Not supported by a valid subscription.)");
            }

            return (
                <ListViewItem
                    leftContent={<ListViewIcon icon={ icon_name } />}
                    heading={ itm.productName }
                    key={itm.productId}
                >
                    <Row>
                        <Col sm={11}>
                            <div className="col-md-11">
                                <dl className="dl-horizontal">
                                    <dt>{ _("Product Name") }</dt>
                                    <dd>{ itm.productName }</dd>
                                    <dt>{ _("Product ID") }</dt>
                                    <dd>{ itm.productId }</dd>
                                    <dt>{ _("Version") }</dt>
                                    <dd>{ itm.version }</dd>
                                    <dt>{ _("Arch") }</dt>
                                    <dd>{ itm.arch }</dd>
                                    <dt>{ _("Status") }</dt>
                                    <dd>{ status_text }</dd>
                                    <dt>{ _("Starts") }</dt>
                                    <dd>{ itm.starts }</dd>
                                    <dt>{ _("Ends") }</dt>
                                    <dd>{ itm.ends }</dd>
                                </dl>
                            </div>
                        </Col>
                    </Row>
                </ListViewItem>
            );
        });

        return (
            <div className="container-fluid">
            <SubscriptionStatus {...this.props }/>
            <Listing
                    title={ _("Installed products") }
                    emptyCaption={ _("No installed products detected.") }
                    >
                <ListView className="installed-products">
                {entries}
                </ListView>
            </Listing>
            </div>
        );
    },
    render: function() {
        if (this.props.status === undefined ||
            this.props.status === 'not-found' ||
            this.props.status === 'access-denied' ||
            !subscriptionsClient.config.loaded) {
            return this.renderCurtains();
        } else {
            return this.renderSubscriptions();
        }
    }
});

module.exports = {
    page: SubscriptionsPage,
};
